import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { FillblankQuestion, FlashcardQuestion, KnowledgeItem } from '../model/Models'
import { KnowledgeCacheService } from './KnowledgeCacheService'
import { Session } from '../store/Session'

const DOMAIN = 0x0000
const TAG = 'FocusStudy'

/* 本地出题使用的词表，与后端 practice.service.ts 保持一致 */
const KNOWN_TERMS: string[] = ['Vue3', 'Vue', 'React', 'TypeScript', 'JavaScript', 'CSS', 'SCSS', 'HTML5', 'Vite', 'Pinia', 'Element Plus', 'NestJS', 'Node.js', 'TypeORM', 'MySQL', 'Redis', 'Docker', '微服务', '前端工程化', '性能优化', 'ref', 'reactive', 'Proxy', 'RefImpl', 'Module', 'Controller', 'Service', 'Entity', 'Repository', 'DI', '依赖注入', '变量提升', '暂时性死区', '响应式', '解构']
const FALLBACK_DISTRACTORS: string[] = ['Docker', 'Redis', 'Vue3', 'NestJS', 'TypeORM', 'MySQL', 'Controller', 'Service', 'Entity', 'Repository', 'Pinia', 'Vite', 'TypeScript', 'Node.js', 'Module', 'Proxy', 'reactive', '依赖注入', '性能优化']
const STOP_WORDS: Set<string> = new Set<string>(['用于', '一个', '这个', '可以', '使用', '负责', '通过', '提供', '进行', '需要', '其中', '以及', '如果', '因为', '所以', '不会', '不能', '存在', '方法', '内容', '数据', '知识', '问题', '什么', '区别', '关系', '基础'])

export const FOCUS_STATUS_RUNNING = 'running'
export const FOCUS_STATUS_PAUSED = 'paused'
export const FOCUS_STATUS_PAUSED_BG = 'pausedBg'
export const FOCUS_STATUS_VERIFY = 'verify'

export interface FocusTaskInput {
  name: string
  dailyTargetMin: number
  minSegmentMin: number
  verifyIntervalMin: number
  bgLimit: number
  dailyLimit: number
  practiceMode: string
  /** 逗号分隔的范围列表：all / learned / unlearned / 标签名，由表单多选生成 */
  practiceRange: string
  practiceCount: number
  rewardEnabled: boolean
  password: string
  viewSeconds: number
}

/** 任务配置创建后只读；today* 为当日进度，跨天自动清零 */
export interface FocusTask extends FocusTaskInput {
  id: number
  createdAt: number
  date: string
  todaySec: number
  completions: number
  viewChances: number
}

export interface FocusActive {
  taskId: number
  elapsedSec: number
  sinceVerifySec: number
  bgCount: number
  status: string
  lastTickAt: number
}

export interface FocusNotice {
  taskId: number
  reason: string
}

export interface FocusSettleResult {
  settledSec: number
  todaySec: number
  targetSec: number
  completions: number
  dailyLimit: number
  earned: number
  viewChances: number
}

export interface ArithmeticQuestion {
  a: number
  b: number
  op: string
  answer: number
}

interface FocusStore {
  nextId: number
  tasks: FocusTask[]
  active: FocusActive | null
  notice: FocusNotice | null
}

export type FocusQuestion = FlashcardQuestion | FillblankQuestion

/**
 * 专注学习本地引擎：任务配置与当日进度按账号存 filesDir JSON，
 * 出题/验证题全本地算（离线可用）；进行中状态落盘，启动时发现残留即判为
 * 「App 被关闭」→ 本段作废。
 */
export class FocusStudyService {
  private static baseDir: string = ''
  private static store: FocusStore | null = null
  private static loadedUserId: number = 0

  static init(context: common.Context): void {
    FocusStudyService.baseDir = context.filesDir
  }

  static list(): FocusTask[] {
    const store = FocusStudyService.ensure()
    let changed = false
    for (const task of store.tasks) {
      if (FocusStudyService.normalizeDay(task)) {
        changed = true
      }
    }
    if (changed) {
      FocusStudyService.save()
    }
    return store.tasks
  }

  static get(id: number): FocusTask | undefined {
    for (const task of FocusStudyService.list()) {
      if (task.id === id) {
        return task
      }
    }
    return undefined
  }

  static create(input: FocusTaskInput): FocusTask {
    const store = FocusStudyService.ensure()
    const task: FocusTask = {
      id: store.nextId,
      name: input.name,
      dailyTargetMin: input.dailyTargetMin,
      minSegmentMin: input.minSegmentMin,
      verifyIntervalMin: input.verifyIntervalMin,
      bgLimit: input.bgLimit,
      dailyLimit: input.dailyLimit,
      practiceMode: input.practiceMode,
      practiceRange: input.practiceRange,
      practiceCount: input.practiceCount,
      rewardEnabled: input.rewardEnabled,
      password: input.password,
      viewSeconds: input.viewSeconds,
      createdAt: Date.now(),
      date: FocusStudyService.todayStr(),
      todaySec: 0,
      completions: 0,
      viewChances: 0
    }
    store.nextId += 1
    store.tasks.push(task)
    FocusStudyService.save()
    return task
  }

  static remove(id: number): void {
    const store = FocusStudyService.ensure()
    store.tasks = store.tasks.filter((task: FocusTask) => task.id !== id)
    const active = store.active
    if (active !== null && active.taskId === id) {
      store.active = null
    }
    FocusStudyService.save()
  }

  /* ---------------- 入门条件 ---------------- */

  /** '' 表示可开始；否则返回不可开始的原因 */
  static canStartReason(task: FocusTask): string {
    if (task.completions >= task.dailyLimit) {
      return '今日完成次数已用完，明天再来'
    }
    if (FocusStudyService.active() !== null) {
      return '已有专注进行中'
    }
    return ''
  }

  /** 当前范围内可用笔记数（本地缓存），用于进入前的空库检查 */
  static rangeCount(task: FocusTask): number {
    return FocusStudyService.filterByRange(KnowledgeCacheService.load(), task.practiceRange).length
  }

  /* ---------------- 段状态机 ---------------- */

  static active(): FocusActive | null {
    return FocusStudyService.ensure().active
  }

  static startSegment(taskId: number): boolean {
    const store = FocusStudyService.ensure()
    if (store.active !== null) {
      return false
    }
    const active: FocusActive = {
      taskId: taskId,
      elapsedSec: 0,
      sinceVerifySec: 0,
      bgCount: 0,
      status: FOCUS_STATUS_RUNNING,
      lastTickAt: Date.now()
    }
    store.active = active
    FocusStudyService.save()
    return true
  }

  static pauseManual(): void {
    const store = FocusStudyService.ensure()
    const active = store.active
    if (active !== null && active.status === FOCUS_STATUS_RUNNING) {
      active.status = FOCUS_STATUS_PAUSED
      FocusStudyService.save()
    }
  }

  static resume(): void {
    const store = FocusStudyService.ensure()
    const active = store.active
    if (active !== null && (active.status === FOCUS_STATUS_PAUSED || active.status === FOCUS_STATUS_PAUSED_BG)) {
      active.status = FOCUS_STATUS_RUNNING
      active.lastTickAt = Date.now()
      FocusStudyService.save()
    }
  }

  /** 页面每秒调用；返回 '' 或 'verify'（该弹验证题了，服务内部已暂停） */
  static tick(): string {
    const store = FocusStudyService.ensure()
    const active = store.active
    if (active === null) {
      return ''
    }
    const now = Date.now()
    if (active.status !== FOCUS_STATUS_RUNNING) {
      active.lastTickAt = now
      return ''
    }
    let delta = Math.floor((now - active.lastTickAt) / 1000)
    active.lastTickAt = now
    if (delta <= 0) {
      return ''
    }
    if (delta > 3) {
      delta = 3
    }
    active.elapsedSec += delta
    active.sinceVerifySec += delta
    const task = FocusStudyService.getRaw(store, active.taskId)
    if (task !== undefined && active.sinceVerifySec >= task.verifyIntervalMin * 60) {
      active.status = FOCUS_STATUS_VERIFY
      FocusStudyService.save()
      return 'verify'
    }
    if (active.elapsedSec % 15 === 0) {
      FocusStudyService.save()
    }
    return ''
  }

  static markVerifyPassed(): void {
    const store = FocusStudyService.ensure()
    const active = store.active
    if (active !== null && active.status === FOCUS_STATUS_VERIFY) {
      active.sinceVerifySec = 0
      active.status = FOCUS_STATUS_RUNNING
      active.lastTickAt = Date.now()
      FocusStudyService.save()
    }
  }

  /** 切后台/息屏：暂停 + 本段计 1 次；超过上限本段作废（留通知给页面） */
  static notifyBackground(): void {
    const store = FocusStudyService.ensure()
    const active = store.active
    if (active === null) {
      return
    }
    active.bgCount += 1
    const task = FocusStudyService.getRaw(store, active.taskId)
    if (task === undefined || active.bgCount > task.bgLimit) {
      store.active = null
      store.notice = { taskId: active.taskId, reason: 'bgLimit' }
      FocusStudyService.save()
      return
    }
    if (active.status === FOCUS_STATUS_RUNNING) {
      active.status = FOCUS_STATUS_PAUSED_BG
    }
    FocusStudyService.save()
  }

  /** 结算当前段：实际时长计入今日累计，跨过目标时长倍数触发完成（叠加查看机会） */
  static settle(): FocusSettleResult | null {
    const store = FocusStudyService.ensure()
    const active = store.active
    if (active === null) {
      return null
    }
    const task = FocusStudyService.getRaw(store, active.taskId)
    store.active = null
    if (task === undefined) {
      FocusStudyService.save()
      return null
    }
    task.todaySec += active.elapsedSec
    const targetSec = task.dailyTargetMin * 60
    const reached = Math.floor(task.todaySec / targetSec)
    const capped = Math.min(reached, task.dailyLimit)
    let earned = capped - task.completions
    if (earned < 0) {
      earned = 0
    }
    task.completions += earned
    task.viewChances += earned
    FocusStudyService.save()
    const result: FocusSettleResult = {
      settledSec: active.elapsedSec,
      todaySec: task.todaySec,
      targetSec: targetSec,
      completions: task.completions,
      dailyLimit: task.dailyLimit,
      earned: earned,
      viewChances: task.viewChances
    }
    return result
  }

  /** 本段作废（不足最少时长主动结束 / 用户确认放弃） */
  static voidSegment(): void {
    const store = FocusStudyService.ensure()
    store.active = null
    FocusStudyService.save()
  }

  static takeNotice(): FocusNotice | null {
    const store = FocusStudyService.ensure()
    const notice = store.notice
    if (notice !== null) {
      store.notice = null
      FocusStudyService.save()
    }
    return notice
  }

  /** 每次查看消耗一个机会 */
  static consumeView(taskId: number): boolean {
    const task = FocusStudyService.get(taskId)
    if (task === undefined || task.viewChances <= 0) {
      return false
    }
    task.viewChances -= 1
    FocusStudyService.save()
    return true
  }

  /* ---------------- 本地出题（移植自后端 practice.service.ts） ---------------- */

  static generateBatch(task: FocusTask): FocusQuestion[] {
    const items = KnowledgeCacheService.load()
    const pool = FocusStudyService.filterByRange(items, task.practiceRange)
    if (pool.length === 0) {
      return []
    }
    const selected = FocusStudyService.shuffle(pool).slice(0, task.practiceCount)
    if (task.practiceMode === 'fillblank') {
      const questions: FocusQuestion[] = []
      for (const note of selected) {
        const question = FocusStudyService.createFillblankQuestion(note, pool)
        if (question !== null) {
          questions.push(question)
        }
      }
      return questions
    }
    const cards: FocusQuestion[] = []
    for (const note of selected) {
      const card: FlashcardQuestion = {
        id: note.id,
        type: 'flashcard',
        title: note.title,
        content: note.content,
        tags: note.tags ?? []
      }
      cards.push(card)
    }
    return cards
  }

  static nextArithmetic(): ArithmeticQuestion {
    const roll = Math.floor(Math.random() * 3)
    if (roll === 0) {
      const a = 23 + Math.floor(Math.random() * 75)
      const b = 23 + Math.floor(Math.random() * 75)
      return { a: a, b: b, op: '+', answer: a + b }
    }
    if (roll === 1) {
      const a = 45 + Math.floor(Math.random() * 55)
      const b = 12 + Math.floor(Math.random() * (a - 11 - 12))
      return { a: a, b: b, op: '-', answer: a - b }
    }
    const a = 12 + Math.floor(Math.random() * 88)
    const b = 2 + Math.floor(Math.random() * 8)
    return { a: a, b: b, op: '×', answer: a * b }
  }

  private static createFillblankQuestion(note: KnowledgeItem, allNotes: KnowledgeItem[]): FillblankQuestion | null {
    const keyword = FocusStudyService.pickKeyword(note)
    if (keyword === null) {
      return null
    }
    const masked = note.content.includes(keyword) ? note.content.replace(keyword, '____') : '____ 是「' + note.title + '」中的关键概念。'
    return {
      id: note.id,
      type: 'fillblank',
      title: note.title + '：' + masked,
      options: FocusStudyService.buildOptions(keyword, note, allNotes),
      correctAnswer: keyword,
      tags: note.tags ?? []
    }
  }

  private static pickKeyword(note: KnowledgeItem): string | null {
    const tags: string[] = []
    for (const tag of note.tags ?? []) {
      const text = String(tag).trim()
      if (text.length > 1) {
        tags.push(text)
      }
    }
    if (tags.length > 0) {
      return FocusStudyService.randomItem(tags)
    }
    const known: string[] = []
    for (const term of KNOWN_TERMS) {
      if (note.title.includes(term) || note.content.includes(term)) {
        known.push(term)
      }
    }
    if (known.length > 0) {
      return FocusStudyService.randomItem(known)
    }
    const extracted = FocusStudyService.extractContentKeywords(note.title + ' ' + note.content)
    return extracted.length > 0 ? FocusStudyService.randomItem(extracted) : null
  }

  private static extractContentKeywords(text: string): string[] {
    const matches = text.match(/[A-Za-z][A-Za-z0-9.+#/-]{1,24}|[\u4e00-\u9fa5]{2,8}/g) ?? []
    const out: string[] = []
    for (const word of matches) {
      if (STOP_WORDS.has(word) || word.length < 2 || /^\d+$/.test(word)) {
        continue
      }
      if (out.indexOf(word) < 0) {
        out.push(word)
      }
    }
    return out
  }

  private static buildOptions(correctAnswer: string, note: KnowledgeItem, allNotes: KnowledgeItem[]): string[] {
    const candidates: string[] = []
    for (const item of allNotes) {
      if (item.id === note.id) {
        continue
      }
      for (const tag of item.tags ?? []) {
        candidates.push(String(tag))
      }
    }
    for (const item of allNotes) {
      if (item.id === note.id) {
        continue
      }
      for (const word of FocusStudyService.extractContentKeywords(item.title)) {
        candidates.push(word)
      }
    }
    for (const term of KNOWN_TERMS) {
      candidates.push(term)
    }
    for (const fallback of FALLBACK_DISTRACTORS) {
      candidates.push(fallback)
    }
    const seen: string[] = []
    const distractors: string[] = []
    for (const candidate of FocusStudyService.shuffle(candidates)) {
      const trimmed = candidate.trim()
      if (trimmed.length === 0) {
        continue
      }
      const lower = trimmed.toLowerCase()
      if (lower === correctAnswer.toLowerCase() || seen.indexOf(lower) >= 0) {
        continue
      }
      seen.push(lower)
      distractors.push(trimmed)
      if (distractors.length === 3) {
        break
      }
    }
    const options: string[] = [correctAnswer]
    for (const distractor of distractors) {
      options.push(distractor)
    }
    return FocusStudyService.shuffle(options)
  }

  private static filterByRange(items: KnowledgeItem[], range: string): KnowledgeItem[] {
    if (range.length === 0 || range === 'all') {
      return items.slice()
    }
    const ranges: string[] = range.split(',')
    const includesLearned: boolean = ranges.indexOf('learned') >= 0
    const includesUnlearned: boolean = ranges.indexOf('unlearned') >= 0
    if (includesLearned && includesUnlearned) {
      return items.slice()
    }
    const tags: string[] = []
    for (const part of ranges) {
      if (part === 'all') {
        return items.slice()
      }
      if (part !== 'learned' && part !== 'unlearned' && part.length > 0) {
        tags.push(part)
      }
    }
    const out: KnowledgeItem[] = []
    for (const note of items) {
      if (includesLearned && note.isLearned) {
        out.push(note)
        continue
      }
      if (includesUnlearned && !note.isLearned) {
        out.push(note)
        continue
      }
      if (tags.length > 0 && FocusStudyService.hasAnyTag(note, tags)) {
        out.push(note)
      }
    }
    return out
  }

  private static hasAnyTag(item: KnowledgeItem, ranges: string[]): boolean {
    for (const tag of item.tags ?? []) {
      const text = String(tag)
      for (const range of ranges) {
        if (text.includes(range)) {
          return true
        }
      }
    }
    return false
  }

  private static shuffle<T>(items: T[]): T[] {
    const result = items.slice()
    for (let index = result.length - 1; index > 0; index -= 1) {
      const randomIndex = Math.floor(Math.random() * (index + 1))
      const temp = result[index]
      result[index] = result[randomIndex]
      result[randomIndex] = temp
    }
    return result
  }

  private static randomItem<T>(items: T[]): T {
    return items[Math.floor(Math.random() * items.length)]
  }

  /* ---------------- 存储 ---------------- */

  /** 跨天清零：今日累计 / 完成次数 / 未用查看机会 */
  private static normalizeDay(task: FocusTask): boolean {
    const today = FocusStudyService.todayStr()
    if (task.date === today) {
      return false
    }
    task.date = today
    task.todaySec = 0
    task.completions = 0
    task.viewChances = 0
    return true
  }

  private static getRaw(store: FocusStore, id: number): FocusTask | undefined {
    for (const task of store.tasks) {
      if (task.id === id) {
        return task
      }
    }
    return undefined
  }

  private static ensure(): FocusStore {
    const userId = Session.user === null ? 0 : Session.user.id
    if (FocusStudyService.store !== null && FocusStudyService.loadedUserId === userId) {
      return FocusStudyService.store
    }
    FocusStudyService.loadedUserId = userId
    FocusStudyService.store = FocusStudyService.load(userId)
    return FocusStudyService.store
  }

  private static load(userId: number): FocusStore {
    const empty: FocusStore = { nextId: 1, tasks: [], active: null, notice: null }
    const path = FocusStudyService.filePath(userId)
    if (path.length === 0) {
      return empty
    }
    try {
      const parsed = JSON.parse(fileIo.readTextSync(path)) as FocusStore
      if (parsed === null || !Array.isArray(parsed.tasks)) {
        return empty
      }
      if (typeof parsed.nextId !== 'number' || parsed.nextId < 1) {
        parsed.nextId = 1
      }
      // 启动时发现残留的进行中状态 = 上次 App 被关闭 → 本段作废
      if (parsed.active !== null && parsed.active !== undefined) {
        const killed = parsed.active
        parsed.active = null
        parsed.notice = { taskId: killed.taskId, reason: 'killed' }
        FocusStudyService.store = parsed
        FocusStudyService.save()
      }
      return parsed
    } catch (err) {
      return empty
    }
  }

  private static save(): void {
    const store = FocusStudyService.store
    if (store === null) {
      return
    }
    const path = FocusStudyService.filePath(FocusStudyService.loadedUserId)
    if (path.length === 0) {
      return
    }
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      try {
        fileIo.writeSync(file.fd, JSON.stringify(store))
      } finally {
        fileIo.closeSync(file)
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'save failed: %{public}s', err instanceof Error ? err.message : JSON.stringify(err))
    }
  }

  private static filePath(userId: number): string {
    if (FocusStudyService.baseDir.length === 0 || userId <= 0) {
      return ''
    }
    return FocusStudyService.baseDir + '/focus_u' + userId.toString() + '.json'
  }

  private static todayStr(): string {
    const now = new Date()
    const month = now.getMonth() + 1
    const day = now.getDate()
    return now.getFullYear().toString() + '-' + (month < 10 ? '0' + month.toString() : month.toString()) + '-' + (day < 10 ? '0' + day.toString() : day.toString())
  }
}

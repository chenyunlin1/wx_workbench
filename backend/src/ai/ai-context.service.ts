import { Injectable } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Between, In, MoreThanOrEqual, Repository } from 'typeorm'
import { Collection, CollectionStatus, CollectionType } from '../collection/collection.entity'
import { Workout, WorkoutIntensity, WorkoutType } from '../workout/workout.entity'
import {
  Finance,
  FinanceType,
  Habit,
  HabitRecord,
  Health,
  Interview,
  InterviewStatus,
  LearningStatus,
  LearningTask,
  Schedule,
  SchedulePriority,
  ShoppingItem,
  ShoppingStatus,
  User,
} from '../entities'
import { Knowledge, KnowledgeType } from '../knowledge/knowledge.entity'
import {
  AI_CONTEXT_MAX_LENGTH,
  AI_CONTEXT_SCOPES,
  AI_SCOPE_LABELS,
  type AiContextScope,
} from './ai.constants'

export interface AiContextSection {
  key: AiContextScope
  title: string
  count: number
  summary: string
}

export interface AiContextSnapshot {
  generatedAt: string
  date: string
  weekday: string
  scope: AiContextScope[]
  sections: AiContextSection[]
  stats: Record<string, number>
  truncated: boolean
  length: number
  text: string
}

interface CollectedSection {
  key: AiContextScope
  lines: string[]
  count: number
  summary: string
  stats?: Record<string, number>
}

const pad = (value: number) => String(value).padStart(2, '0')

const toDateString = (date: Date) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`

const toTimeString = (date: Date) => `${pad(date.getHours())}:${pad(date.getMinutes())}`

const toDateTimeString = (date: Date) => `${toDateString(date)} ${toTimeString(date)}`

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

const money = (value: number) => value.toFixed(2)

const PRIORITY_LABELS: Record<SchedulePriority, string> = {
  [SchedulePriority.HIGH]: '高',
  [SchedulePriority.MEDIUM]: '中',
  [SchedulePriority.LOW]: '低',
}

const LEARNING_LABELS: Record<LearningStatus, string> = {
  [LearningStatus.TODO]: '待开始',
  [LearningStatus.DOING]: '进行中',
  [LearningStatus.DONE]: '已完成',
}

const COLLECTION_TYPE_LABELS: Record<CollectionType, string> = {
  [CollectionType.BOOK]: '书籍',
  [CollectionType.MOVIE]: '影视',
  [CollectionType.MUSIC]: '音乐',
}

const COLLECTION_STATUS_LABELS: Record<CollectionStatus, Record<CollectionType, string>> = {
  [CollectionStatus.WISH]: { book: '想读', movie: '想看', music: '想听' },
  [CollectionStatus.DOING]: { book: '在读', movie: '在看', music: '在听' },
  [CollectionStatus.DONE]: { book: '读完', movie: '看完', music: '听完' },
}

const WORKOUT_TYPE_LABELS: Record<WorkoutType, string> = {
  [WorkoutType.RUNNING]: '跑步',
  [WorkoutType.STRENGTH]: '力量训练',
  [WorkoutType.CYCLING]: '骑行',
  [WorkoutType.SWIMMING]: '游泳',
  [WorkoutType.YOGA]: '瑜伽',
  [WorkoutType.HIIT]: 'HIIT',
  [WorkoutType.WALKING]: '快走',
  [WorkoutType.OTHER]: '其他',
}

const WORKOUT_INTENSITY_LABELS: Record<WorkoutIntensity, string> = {
  [WorkoutIntensity.LOW]: '低强度',
  [WorkoutIntensity.MEDIUM]: '中等强度',
  [WorkoutIntensity.HIGH]: '高强度',
}

const INTERVIEW_LABELS: Record<InterviewStatus, string> = {
  [InterviewStatus.PENDING]: '待进行',
  [InterviewStatus.PASSED]: '已通过',
  [InterviewStatus.REJECTED]: '未通过',
  [InterviewStatus.CANCELLED]: '已取消',
}

const truncate = (text: string, max: number) => {
  const flat = text.replace(/\s+/g, ' ').trim()
  return flat.length > max ? `${flat.slice(0, max)}…` : flat
}

const KNOWLEDGE_SECTION_BUDGET = 6000

/**
 * 汇总当前用户的平台数据，渲染成一段可直接塞进 system 消息的 Markdown 快照。
 */
@Injectable()
export class AiContextService {
  constructor(
    @InjectRepository(Schedule)
    private readonly scheduleRepository: Repository<Schedule>,
    @InjectRepository(Habit)
    private readonly habitRepository: Repository<Habit>,
    @InjectRepository(HabitRecord)
    private readonly habitRecordRepository: Repository<HabitRecord>,
    @InjectRepository(LearningTask)
    private readonly learningTaskRepository: Repository<LearningTask>,
    @InjectRepository(Interview)
    private readonly interviewRepository: Repository<Interview>,
    @InjectRepository(Finance)
    private readonly financeRepository: Repository<Finance>,
    @InjectRepository(Health)
    private readonly healthRepository: Repository<Health>,
    @InjectRepository(ShoppingItem)
    private readonly shoppingRepository: Repository<ShoppingItem>,
    @InjectRepository(Knowledge)
    private readonly knowledgeRepository: Repository<Knowledge>,
    @InjectRepository(Collection)
    private readonly collectionRepository: Repository<Collection>,
    @InjectRepository(Workout)
    private readonly workoutRepository: Repository<Workout>,
  ) {}

  /** 未传范围时默认读取全部；显式传空数组表示不读取任何数据。 */
  normalizeScope(scope?: string[] | null): AiContextScope[] {
    if (scope === undefined || scope === null) return [...AI_CONTEXT_SCOPES]
    const valid = new Set<string>(AI_CONTEXT_SCOPES)
    const picked = scope.filter((item): item is AiContextScope => valid.has(item))
    // 固定顺序，保证同样的范围生成同样的快照
    return AI_CONTEXT_SCOPES.filter((item) => picked.includes(item))
  }

  async build(user: User, scope?: string[] | null): Promise<AiContextSnapshot> {
    const now = new Date()
    const activeScope = this.normalizeScope(scope)

    const collected = await Promise.all(
      activeScope.map((key) => this.collect(user.id, key, now)),
    )

    const header = [
      '# LifeOS 个人数据快照',
      `生成时间：${toDateTimeString(now)}（${WEEKDAYS[now.getDay()]}）`,
      `用户：${user.username}${user.role === 'admin' ? '（管理员）' : ''}`,
    ]

    const body = collected
      .filter((section) => section.lines.length > 0)
      .map((section) =>
        [`## ${AI_SCOPE_LABELS[section.key]}（${section.summary}）`, ...section.lines].join('\n'),
      )

    const emptySections = collected.filter((section) => section.lines.length === 0)
    const footer = emptySections.length
      ? [
          `> 以下范围当前没有任何记录：${emptySections
            .map((section) => AI_SCOPE_LABELS[section.key])
            .join('、')}。`,
          '> 回答时请如实说明缺少记录，不要编造数据。',
        ]
      : ['> 以上为用户的真实数据，回答个人数据相关问题时应以此为准。']

    // header / body / footer 各自成块，块之间空一行
    let text = [header.join('\n'), body.join('\n\n'), footer.join('\n')]
      .filter((block) => block.length > 0)
      .join('\n\n')
    let truncated = false
    if (text.length > AI_CONTEXT_MAX_LENGTH) {
      text = `${text.slice(0, AI_CONTEXT_MAX_LENGTH)}\n…（数据快照过长已截断）`
      truncated = true
    }

    const stats: Record<string, number> = {}
    for (const section of collected) Object.assign(stats, section.stats ?? {})

    return {
      generatedAt: now.toISOString(),
      date: toDateString(now),
      weekday: WEEKDAYS[now.getDay()],
      scope: activeScope,
      sections: collected.map((section) => ({
        key: section.key,
        title: AI_SCOPE_LABELS[section.key],
        count: section.count,
        summary: section.summary,
      })),
      stats,
      truncated,
      length: text.length,
      text,
    }
  }

  private collect(userId: number, key: AiContextScope, now: Date): Promise<CollectedSection> {
    switch (key) {
      case 'schedules':
        return this.collectSchedules(userId, now)
      case 'habits':
        return this.collectHabits(userId, now)
      case 'learning':
        return this.collectLearning(userId)
      case 'knowledge':
        return this.collectKnowledge(userId)
      case 'collections':
        return this.collectCollections(userId)
      case 'interviews':
        return this.collectInterviews(userId, now)
      case 'finance':
        return this.collectFinance(userId, now)
      case 'health':
        return this.collectHealth(userId)
      case 'workouts':
        return this.collectWorkouts(userId, now)
      case 'shopping':
        return this.collectShopping(userId)
      default:
        return Promise.resolve({
          key,
          lines: [],
          count: 0,
          summary: '未支持',
        })
    }
  }

  private async collectSchedules(userId: number, now: Date): Promise<CollectedSection> {
    const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const rangeEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7, 23, 59, 59, 999)
    const rows = await this.scheduleRepository.find({
      where: { userId, startTime: Between(dayStart, rangeEnd) },
      order: { startTime: 'ASC' },
      take: 30,
    })

    const lines = rows.map((row) => {
      const start = `${toDateString(row.startTime)} ${toTimeString(row.startTime)}`
      const end = row.endTime ? `-${toTimeString(row.endTime)}` : ''
      const flags = [PRIORITY_LABELS[row.priority], row.completed ? '已完成' : '未完成']
      return `- ${start}${end} ${row.title}（${row.category}｜${flags.join('｜')}）`
    })

    const todayRows = rows.filter((row) => toDateString(row.startTime) === toDateString(now))
    return {
      key: 'schedules',
      lines,
      count: rows.length,
      summary: `今日 ${todayRows.length} 项，未来 7 天共 ${rows.length} 项`,
      stats: { schedules: rows.length, schedulesToday: todayRows.length },
    }
  }

  private async collectHabits(userId: number, now: Date): Promise<CollectedSection> {
    const habits = await this.habitRepository.find({
      where: { userId },
      order: { id: 'DESC' },
      take: 30,
    })

    if (!habits.length) {
      return { key: 'habits', lines: [], count: 0, summary: '暂无习惯', stats: { habits: 0 } }
    }

    const records = await this.habitRecordRepository.find({
      where: {
        habitId: In(habits.map((habit) => habit.id)),
        checkInDate: toDateString(now),
      },
    })
    const checkedIds = new Set(records.map((record) => record.habitId))

    const lines = habits.map(
      (habit) =>
        `- ${habit.icon} ${habit.name}｜连续 ${habit.streakDays} 天｜${
          checkedIds.has(habit.id) ? '今日已打卡' : '今日未打卡'
        }`,
    )

    return {
      key: 'habits',
      lines,
      count: habits.length,
      summary: `${habits.length} 个习惯，今日已打卡 ${checkedIds.size} 个`,
      stats: { habits: habits.length, habitsCheckedToday: checkedIds.size },
    }
  }

  private async collectLearning(userId: number): Promise<CollectedSection> {
    const tasks = await this.learningTaskRepository.find({
      where: { userId },
      order: { id: 'DESC' },
      take: 30,
    })

    const done = tasks.filter((task) => task.status === LearningStatus.DONE)
    const lines = tasks.map(
      (task) => `- [${LEARNING_LABELS[task.status]}] ${task.title}（${task.duration} 分钟）`,
    )

    return {
      key: 'learning',
      lines,
      count: tasks.length,
      summary: `${tasks.length} 个学习任务，已完成 ${done.length} 个，累计 ${done.reduce(
        (sum, task) => sum + task.duration,
        0,
      )} 分钟`,
      stats: { learningTasks: tasks.length, learningDone: done.length },
    }
  }

  private async collectKnowledge(userId: number): Promise<CollectedSection> {
    const [total, learned, items] = await Promise.all([
      this.knowledgeRepository.count({ where: { userId } }),
      this.knowledgeRepository.count({ where: { userId, isLearned: true } }),
      this.knowledgeRepository.find({
        where: { userId },
        order: { updatedAt: 'DESC' },
        take: 30,
      }),
    ])

    if (!items.length) {
      return {
        key: 'knowledge',
        lines: [],
        count: 0,
        summary: '知识库为空',
        stats: { knowledge: 0, knowledgeLearned: 0 },
      }
    }

    const lines: string[] = []
    let budget = KNOWLEDGE_SECTION_BUDGET
    let listed = 0

    for (const item of items) {
      const tags = item.tags?.length ? `｜标签：${item.tags.join('、')}` : ''
      const type = item.type === KnowledgeType.QA ? '问答' : '笔记'
      const head = `- [${type}] ${item.title}${tags}｜${item.isLearned ? '已学习' : '未学习'}`
      const excerpt = `（摘要：${truncate(item.content, 200)}）`
      const entry = `${head}\n  ${excerpt}`

      if (entry.length > budget) break
      budget -= entry.length
      lines.push(entry)
      listed += 1
    }

    if (listed < items.length) {
      lines.push(`- 其余 ${items.length - listed} 条知识未列出，如需可让用户说明具体主题。`)
    }

    return {
      key: 'knowledge',
      lines,
      count: total,
      summary: `共 ${total} 条，已学习 ${learned} 条，已列出 ${listed} 条`,
      stats: { knowledge: total, knowledgeLearned: learned, knowledgeListed: listed },
    }
  }

  private async collectCollections(userId: number): Promise<CollectedSection> {
    const [items, total] = await Promise.all([
      this.collectionRepository.find({
        where: { userId },
        order: { createdAt: 'DESC' },
        take: 30,
      }),
      this.collectionRepository.count({ where: { userId } }),
    ])

    if (!items.length) {
      return {
        key: 'collections',
        lines: [],
        count: 0,
        summary: '暂无收藏',
        stats: { collections: 0 },
      }
    }

    const finished = items.filter((item) => item.status === CollectionStatus.DONE).length

    const lines = items.map((item) => {
      const meta = [
        COLLECTION_TYPE_LABELS[item.type],
        COLLECTION_STATUS_LABELS[item.status][item.type],
        item.rating ? `评分 ${item.rating}` : '未评分',
        item.year ? `${item.year} 年` : null,
      ].filter(Boolean)
      const comment = item.comment ? `｜短评：${truncate(item.comment, 60)}` : ''
      return `- ${item.title}（${meta.join('｜')}）${comment}`
    })

    return {
      key: 'collections',
      lines,
      count: total,
      summary: `共 ${total} 条，已列出 ${items.length} 条，其中已完成 ${finished} 条`,
      stats: { collections: total, collectionsFinished: finished },
    }
  }

  private async collectInterviews(userId: number, now: Date): Promise<CollectedSection> {
    const upcoming = await this.interviewRepository.find({
      where: { userId, interviewTime: MoreThanOrEqual(now) },
      order: { interviewTime: 'ASC' },
      take: 10,
    })
    const all = await this.interviewRepository.count({ where: { userId } })

    const lines = upcoming.map(
      (interview) =>
        `- ${toDateTimeString(interview.interviewTime)} ${interview.company} · ${
          interview.position
        }｜${INTERVIEW_LABELS[interview.status]}`,
    )

    return {
      key: 'interviews',
      lines,
      count: upcoming.length,
      summary: `共 ${all} 场，待进行 ${upcoming.length} 场`,
      stats: { interviews: all, interviewsUpcoming: upcoming.length },
    }
  }

  private async collectFinance(userId: number, now: Date): Promise<CollectedSection> {
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999)
    const previousStart = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    const previousEnd = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999)

    const [current, previous] = await Promise.all([
      this.financeRepository.find({
        where: { userId, recordDate: Between(monthStart, monthEnd) },
        order: { recordDate: 'DESC' },
      }),
      this.financeRepository.find({
        where: { userId, recordDate: Between(previousStart, previousEnd) },
        select: ['id', 'type', 'amount'],
      }),
    ])

    const sumBy = (rows: Finance[], type: FinanceType) =>
      rows
        .filter((row) => row.type === type)
        .reduce((sum, row) => sum + Number(row.amount), 0)

    const income = sumBy(current, FinanceType.INCOME)
    const expense = sumBy(current, FinanceType.EXPENSE)
    const previousIncome = sumBy(previous, FinanceType.INCOME)
    const previousExpense = sumBy(previous, FinanceType.EXPENSE)

    const expenseByCategory = new Map<string, number>()
    for (const row of current) {
      if (row.type !== FinanceType.EXPENSE) continue
      expenseByCategory.set(row.category, (expenseByCategory.get(row.category) ?? 0) + Number(row.amount))
    }

    const lines = [
      `- 本月（${toDateString(monthStart).slice(0, 7)}）：收入 ${money(income)} 元，支出 ${money(
        expense,
      )} 元，结余 ${money(income - expense)} 元`,
      `- 上月：收入 ${money(previousIncome)} 元，支出 ${money(previousExpense)} 元`,
    ]

    if (expenseByCategory.size) {
      const categories = [...expenseByCategory.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([category, amount]) => `${category} ${money(amount)} 元`)
        .join('；')
      lines.push(`- 本月支出分类：${categories}`)
    }

    if (current.length) {
      lines.push('- 本月明细（最多 10 条）：')
      for (const row of current.slice(0, 10)) {
        const label = row.type === FinanceType.INCOME ? '收入' : '支出'
        const remark = row.remark ? `｜${row.remark}` : ''
        lines.push(
          `  - ${toDateString(row.recordDate)} ${label} ${money(Number(row.amount))} 元｜${
            row.category
          }${remark}`,
        )
      }
    }

    return {
      key: 'finance',
      lines,
      count: current.length,
      summary: `本月 ${current.length} 笔，结余 ${money(income - expense)} 元`,
      stats: { financeRecords: current.length },
    }
  }

  private async collectHealth(userId: number): Promise<CollectedSection> {
    const rows = await this.healthRepository.find({
      where: { userId },
      order: { recordDate: 'DESC' },
      take: 10,
    })

    if (!rows.length) {
      return { key: 'health', lines: [], count: 0, summary: '暂无健康记录', stats: { health: 0 } }
    }

    const ordered = [...rows].reverse()
    const recent7 = ordered.slice(-7)
    const average = recent7.reduce((sum, row) => sum + Number(row.weight), 0) / recent7.length
    const latest = ordered.at(-1)

    const lines = ordered.map((row) => `- ${row.recordDate} 体重 ${Number(row.weight)} kg`)
    lines.unshift(
      `- 最近一次：${latest?.recordDate} ${latest ? Number(latest.weight) : '-'} kg；近 ${
        recent7.length
      } 次平均 ${average.toFixed(2)} kg`,
    )

    return {
      key: 'health',
      lines,
      count: rows.length,
      summary: `近 ${recent7.length} 次平均 ${average.toFixed(1)} kg`,
      stats: { healthRecords: rows.length },
    }
  }

  private async collectWorkouts(userId: number, now: Date): Promise<CollectedSection> {
    const rows = await this.workoutRepository.find({
      where: { userId },
      order: { workoutDate: 'DESC' },
      take: 30,
    })

    if (!rows.length) {
      return { key: 'workouts', lines: [], count: 0, summary: '暂无训练记录', stats: { workouts: 0 } }
    }

    const weekStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6)
    const week = rows.filter((row) => row.workoutDate >= weekStart)
    const weekDuration = week.reduce((sum, row) => sum + row.duration, 0)
    const weekCalories = week.reduce((sum, row) => sum + Number(row.calories ?? 0), 0)

    const lines = rows.slice(0, 12).map((row) => {
      const meta = [
        WORKOUT_TYPE_LABELS[row.type],
        `${row.duration} 分钟`,
        WORKOUT_INTENSITY_LABELS[row.intensity],
        row.calories ? `${row.calories} 千卡` : null,
        row.distance ? `${Number(row.distance)} 公里` : null,
      ].filter(Boolean)
      const note = row.note ? `｜${truncate(row.note, 40)}` : ''
      return `- ${toDateString(row.workoutDate)} ${row.title ?? WORKOUT_TYPE_LABELS[row.type]}（${meta.join(
        '｜',
      )}）${note}`
    })

    return {
      key: 'workouts',
      lines,
      count: rows.length,
      summary: `近 7 天 ${week.length} 次、${weekDuration} 分钟、消耗 ${weekCalories} 千卡`,
      stats: {
        workouts: rows.length,
        workoutsWeek: week.length,
        workoutsWeekDuration: weekDuration,
      },
    }
  }

  private async collectShopping(userId: number): Promise<CollectedSection> {
    const [pending, boughtCount] = await Promise.all([
      this.shoppingRepository.find({
        where: { userId, status: ShoppingStatus.PENDING },
        order: { id: 'DESC' },
        take: 20,
      }),
      this.shoppingRepository.count({ where: { userId, status: ShoppingStatus.BOUGHT } }),
    ])

    const total = pending.reduce((sum, item) => sum + Number(item.price), 0)
    const lines = pending.map((item) => `- ${item.name}｜${money(Number(item.price))} 元`)

    return {
      key: 'shopping',
      lines,
      count: pending.length,
      summary: `待买 ${pending.length} 项，合计 ${money(total)} 元，已买 ${boughtCount} 项`,
      stats: { shoppingPending: pending.length, shoppingBought: boughtCount },
    }
  }
}

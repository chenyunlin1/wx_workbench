import { Injectable } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { FindOptionsWhere, Like, Repository } from 'typeorm'
import { Knowledge } from '../knowledge/knowledge.entity'
import { GeneratePracticeDto, PracticeMode, SubmitPracticeResultDto } from './dto/generate-practice.dto'

const KNOWN_TERMS = ['Vue3', 'Vue', 'React', 'TypeScript', 'JavaScript', 'CSS', 'SCSS', 'HTML5', 'Vite', 'Pinia', 'Element Plus', 'NestJS', 'Node.js', 'TypeORM', 'MySQL', 'Redis', 'Docker', '微服务', '前端工程化', '性能优化', 'ref', 'reactive', 'Proxy', 'RefImpl', 'Module', 'Controller', 'Service', 'Entity', 'Repository', 'DI', '依赖注入', '变量提升', '暂时性死区', '响应式', '解构']
const FALLBACK_DISTRACTORS = ['Docker', 'Redis', 'Vue3', 'NestJS', 'TypeORM', 'MySQL', 'Controller', 'Service', 'Entity', 'Repository', 'Pinia', 'Vite', 'TypeScript', 'Node.js', 'Module', 'Proxy', 'reactive', '依赖注入', '性能优化']
const STOP_WORDS = new Set(['用于', '一个', '这个', '可以', '使用', '负责', '通过', '提供', '进行', '需要', '其中', '以及', '如果', '因为', '所以', '不会', '不能', '存在', '方法', '内容', '数据', '知识', '问题', '什么', '区别', '关系', '基础'])

export interface FlashcardQuestion { id: number; type: 'flashcard'; title: string; content: string; tags: string[] }
export interface FillblankQuestion { id: number; type: 'fillblank'; title: string; options: string[]; correctAnswer: string; tags: string[] }

@Injectable()
export class PracticeService {
  constructor(@InjectRepository(Knowledge) private readonly knowledgeRepository: Repository<Knowledge>) {}

  async getTags(userId: number) {
    const notes = await this.knowledgeRepository.find({ where: { userId }, select: { id: true, tags: true } })
    return [...new Set(notes.flatMap((note) => note.tags ?? []).map((tag) => String(tag).trim()).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'zh-CN'))
  }

  countByRange(userId: number, range = 'all') {
    return this.knowledgeRepository.count({ where: this.buildWhere(userId, range) })
  }

  async generate(userId: number, dto: GeneratePracticeDto) {
    const notes = await this.knowledgeRepository.find({ where: this.buildWhere(userId, dto.range), order: { updatedAt: 'DESC' } })
    if (!notes.length) return []
    const selectedNotes = this.shuffle(notes).slice(0, dto.count)
    if (dto.mode === PracticeMode.FLASHCARD) {
      return selectedNotes.map<FlashcardQuestion>((note) => ({ id: note.id, type: 'flashcard', title: note.title, content: note.content, tags: note.tags ?? [] }))
    }
    return selectedNotes.map((note) => this.createFillblankQuestion(note, notes)).filter((question): question is FillblankQuestion => question !== null)
  }

  submitResult(dto: SubmitPracticeResultDto) {
    // 练习结果不写入数据库，只在本次前端会话内展示。
    return { accepted: true, persisted: false, summary: dto }
  }

  private createFillblankQuestion(note: Knowledge, allNotes: Knowledge[]): FillblankQuestion | null {
    const keyword = this.pickKeyword(note)
    if (!keyword) return null
    const maskedContent = note.content.includes(keyword) ? note.content.replace(keyword, '____') : `____ 是「${note.title}」中的关键概念。`
    return { id: note.id, type: 'fillblank', title: `${note.title}：${maskedContent}`, options: this.buildOptions(keyword, note, allNotes), correctAnswer: keyword, tags: note.tags ?? [] }
  }

  private pickKeyword(note: Knowledge) {
    const tags = (note.tags ?? []).map(String).filter((tag) => tag.length > 1)
    if (tags.length) return this.randomItem(tags)
    const known = KNOWN_TERMS.filter((term) => note.title.includes(term) || note.content.includes(term))
    if (known.length) return this.randomItem(known)
    const extracted = this.extractContentKeywords(`${note.title} ${note.content}`)
    return extracted.length ? this.randomItem(extracted) : null
  }

  private extractContentKeywords(text: string) {
    const matches = text.match(/[A-Za-z][A-Za-z0-9.+#/-]{1,24}|[\u4e00-\u9fa5]{2,8}/g) ?? []
    return [...new Set(matches.filter((word) => !STOP_WORDS.has(word) && !/^\d+$/.test(word) && word.length >= 2))]
  }

  private buildOptions(correctAnswer: string, note: Knowledge, allNotes: Knowledge[]) {
    const otherNotes = allNotes.filter((item) => item.id !== note.id)
    const candidates = [...otherNotes.flatMap((item) => item.tags ?? []), ...otherNotes.flatMap((item) => this.extractContentKeywords(item.title)), ...KNOWN_TERMS, ...FALLBACK_DISTRACTORS]
      .map((item) => String(item).trim())
      .filter((item) => item && item.toLowerCase() !== correctAnswer.toLowerCase())
    const distractors: string[] = []
    for (const candidate of this.shuffle([...new Set(candidates)])) {
      if (!distractors.some((item) => item.toLowerCase() === candidate.toLowerCase())) distractors.push(candidate)
      if (distractors.length === 3) break
    }
    return this.shuffle([correctAnswer, ...distractors])
  }

  private buildWhere(userId: number, range: string): FindOptionsWhere<Knowledge>[] {
    const filters: FindOptionsWhere<Knowledge> = {}
    if (range === 'learned') filters.isLearned = true
    else if (range === 'unlearned') filters.isLearned = false
    else if (range && range !== 'all') filters.tags = Like(`%${range}%`)
    return [{ userId, ...filters }, { isPublic: true, ...filters }]
  }

  private shuffle<T>(items: T[]) {
    const result = [...items]
    for (let index = result.length - 1; index > 0; index -= 1) {
      const randomIndex = Math.floor(Math.random() * (index + 1))
      ;[result[index], result[randomIndex]] = [result[randomIndex], result[index]]
    }
    return result
  }

  private randomItem<T>(items: T[]) { return items[Math.floor(Math.random() * items.length)] }
}
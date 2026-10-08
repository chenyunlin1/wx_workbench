import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { parse } from 'csv-parse/sync'
import { stringify } from 'csv-stringify/sync'
import { FindOptionsOrder, FindOptionsWhere, Like, Repository } from 'typeorm'
import { CreateKnowledgeDto } from './dto/create-knowledge.dto'
import { QueryKnowledgeDto } from './dto/query-knowledge.dto'
import { UpdateKnowledgeDto } from './dto/update-knowledge.dto'
import { Knowledge, KnowledgeType } from './knowledge.entity'

interface CsvKnowledgeRow {
  type?: string
  title?: string
  content?: string
  tags?: string
  isLearned?: string
  isPublic?: string
  类型?: string
  标题?: string
  内容?: string
  标签?: string
  已学习?: string
  公开?: string
  [key: string]: string | undefined
}

@Injectable()
export class KnowledgeService {
  constructor(
    @InjectRepository(Knowledge)
    private readonly knowledgeRepository: Repository<Knowledge>,
  ) {}

  async findAll(userId: number, query: QueryKnowledgeDto) {
    const page = Number(query.page) || 1
    const pageSize = Number(query.pageSize) || 20
    const where = this.buildWhere(userId, query)
    const order = { [query.sortBy || 'updatedAt']: 'DESC' } as FindOptionsOrder<Knowledge>

    const [items, total] = await this.knowledgeRepository.findAndCount({
      where,
      order,
      skip: (page - 1) * pageSize,
      take: pageSize,
    })

    return { items, total, page, pageSize }
  }

  async findOne(id: number, userId: number) {
    const knowledge = await this.knowledgeRepository.findOne({
      where: [
        { id, userId },
        { id, isPublic: true },
      ],
    })
    if (!knowledge) throw new NotFoundException('知识条目不存在')

    await this.knowledgeRepository.increment({ id }, 'views', 1)
    knowledge.views += 1
    return knowledge
  }

  create(userId: number, dto: CreateKnowledgeDto) {
    const knowledge = this.knowledgeRepository.create({
      ...dto,
      tags: this.normalizeTags(dto.tags),
      userId,
    })
    return this.knowledgeRepository.save(knowledge)
  }

  async update(id: number, userId: number, dto: UpdateKnowledgeDto) {
    const knowledge = await this.knowledgeRepository.findOne({ where: { id, userId } })
    if (!knowledge) throw new NotFoundException('知识条目不存在')

    Object.assign(knowledge, {
      ...dto,
      ...(dto.tags ? { tags: this.normalizeTags(dto.tags) } : {}),
    })
    return this.knowledgeRepository.save(knowledge)
  }

  async remove(id: number, userId: number) {
    const knowledge = await this.knowledgeRepository.findOne({ where: { id, userId } })
    if (!knowledge) throw new NotFoundException('知识条目不存在')
    await this.knowledgeRepository.remove(knowledge)
    return { success: true }
  }

  async getTags(userId: number) {
    const items = await this.knowledgeRepository.find({
      where: [{ userId }, { isPublic: true }],
      select: { id: true, tags: true },
    })

    return [
      ...new Set(
        items
          .flatMap((item) => item.tags ?? [])
          .map((tag) => String(tag).trim())
          .filter(Boolean),
      ),
    ].sort((a, b) => a.localeCompare(b, 'zh-CN'))
  }

  async exportCsv(userId: number, query: Partial<QueryKnowledgeDto> = {}) {
    const items = await this.knowledgeRepository.find({
      where: this.buildWhere(userId, query),
      order: { [query.sortBy || 'updatedAt']: 'DESC' } as FindOptionsOrder<Knowledge>,
    })

    const records = items.map((item) => ({
      type: item.type,
      title: item.title,
      content: item.content,
      tags: (item.tags ?? []).join('|'),
      isLearned: item.isLearned ? 'true' : 'false',
      isPublic: item.isPublic ? 'true' : 'false',
      views: String(item.views ?? 0),
      createdAt: item.createdAt?.toISOString() ?? '',
      updatedAt: item.updatedAt?.toISOString() ?? '',
    }))

    const csv = stringify(records, {
      header: true,
      columns: ['type', 'title', 'content', 'tags', 'isLearned', 'isPublic', 'views', 'createdAt', 'updatedAt'],
    })

    return `\uFEFF${csv}`
  }

  async importCsv(userId: number, file?: Express.Multer.File) {
    if (!file?.buffer) throw new BadRequestException('请上传 CSV 文件')

    let rows: CsvKnowledgeRow[]
    try {
      rows = parse(file.buffer, {
        columns: true,
        skip_empty_lines: true,
        trim: true,
        bom: true,
      }) as CsvKnowledgeRow[]
    } catch {
      throw new BadRequestException('CSV 文件格式不正确')
    }

    let imported = 0
    let skipped = 0
    const validItems: Knowledge[] = []

    for (const row of rows) {
      const title = String(row.title ?? row['标题'] ?? '').trim()
      const content = String(row.content ?? row['内容'] ?? '').trim()
      const typeValue = String(row.type ?? row['类型'] ?? '').trim().toLowerCase()
      const type = this.normalizeType(typeValue)

      if (!title || !content || !type) {
        skipped += 1
        continue
      }

      const tags = this.normalizeTags(
        String(row.tags ?? row['标签'] ?? '')
          .split(/[|,，]/)
          .map((tag) => tag.trim())
          .filter(Boolean),
      )
      const learnedValue = String(row.isLearned ?? row['已学习'] ?? '').toLowerCase()
      const isLearned = ['true', '1', 'yes', '是', '已学习'].includes(learnedValue)
      const publicValue = String(row.isPublic ?? row['公开'] ?? '').toLowerCase()
      const isPublic = ['true', '1', 'yes', '是', '公开', '公共', 'public'].includes(publicValue)

      validItems.push(
        this.knowledgeRepository.create({
          type,
          title,
          content,
          tags,
          isLearned,
          isPublic,
          userId,
        }),
      )
      imported += 1
    }

    if (validItems.length) await this.knowledgeRepository.save(validItems)
    return { imported, skipped }
  }

  private buildWhere(
    userId: number,
    query: Partial<QueryKnowledgeDto>,
  ): FindOptionsWhere<Knowledge>[] {
    const filters: FindOptionsWhere<Knowledge> = {}
    if (query.type) filters.type = query.type
    if (query.tag) filters.tags = Like(`%${query.tag}%`)

    const scopes: FindOptionsWhere<Knowledge>[] = [{ userId }, { isPublic: true }]
    const keyword = query.keyword?.trim()
    if (!keyword) return scopes.map((scope) => ({ ...scope, ...filters }))

    return scopes.flatMap((scope) => [
      { ...scope, ...filters, title: Like(`%${keyword}%`) },
      { ...scope, ...filters, content: Like(`%${keyword}%`) },
    ])
  }

  private normalizeTags(tags?: string[]) {
    return [...new Set((tags ?? []).map((tag) => String(tag).trim()).filter(Boolean))]
  }

  private normalizeType(value: string): KnowledgeType | null {
    const normalized = value.toLowerCase()
    if (['note', '笔记', 'notes'].includes(normalized)) return KnowledgeType.NOTE
    if (['qa', 'question', '问答', '问题'].includes(normalized)) return KnowledgeType.QA
    return null
  }
}
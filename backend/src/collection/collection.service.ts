import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Between, Repository } from 'typeorm'
import { Collection, CollectionStatus, CollectionType } from './collection.entity'
import { CreateCollectionDto } from './dto/create-collection.dto'
import { QueryCollectionDto } from './dto/query-collection.dto'
import { UpdateCollectionDto } from './dto/update-collection.dto'

const SORT_COLUMNS: Record<string, { column: string; direction: 'ASC' | 'DESC' }> = {
  createdAt: { column: 'collection.createdAt', direction: 'DESC' },
  rating: { column: 'collection.rating', direction: 'DESC' },
  year: { column: 'collection.year', direction: 'DESC' },
  title: { column: 'collection.title', direction: 'ASC' },
}

@Injectable()
export class CollectionService {
  constructor(
    @InjectRepository(Collection)
    private readonly collectionRepository: Repository<Collection>,
  ) {}

  async findAll(userId: number, query: QueryCollectionDto) {
    const page = Number(query.page) || 1
    const pageSize = Number(query.pageSize) || 24

    const builder = this.collectionRepository
      .createQueryBuilder('collection')
      .where('collection.userId = :userId', { userId })

    if (query.type) builder.andWhere('collection.type = :type', { type: query.type })
    if (query.status) builder.andWhere('collection.status = :status', { status: query.status })
    if (query.year) builder.andWhere('collection.year = :year', { year: query.year })

    const keyword = query.keyword?.trim()
    if (keyword) {
      builder.andWhere('(collection.title LIKE :keyword OR collection.comment LIKE :keyword)', {
        keyword: `%${keyword}%`,
      })
    }

    const sort = SORT_COLUMNS[query.sortBy] ?? SORT_COLUMNS.createdAt
    const [items, total] = await builder
      .orderBy(sort.column, sort.direction)
      .addOrderBy('collection.id', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount()

    return { items, total, page, pageSize }
  }

  async findOne(id: number, userId: number) {
    const item = await this.collectionRepository.findOne({ where: { id, userId } })
    if (!item) throw new NotFoundException('收藏不存在')
    return item
  }

  create(userId: number, dto: CreateCollectionDto) {
    return this.collectionRepository.save(
      this.collectionRepository.create({
        type: dto.type,
        title: dto.title.trim(),
        status: dto.status ?? CollectionStatus.WISH,
        rating: dto.rating ?? null,
        year: dto.year ?? null,
        coverUrl: dto.coverUrl?.trim() || null,
        comment: dto.comment?.trim() || null,
        userId,
      }),
    )
  }

  async update(id: number, userId: number, dto: UpdateCollectionDto) {
    const item = await this.findOne(id, userId)
    Object.assign(item, {
      ...dto,
      ...(dto.title !== undefined ? { title: dto.title.trim() } : {}),
      ...(dto.coverUrl !== undefined ? { coverUrl: dto.coverUrl?.trim() || null } : {}),
      ...(dto.comment !== undefined ? { comment: dto.comment?.trim() || null } : {}),
      ...(dto.rating !== undefined ? { rating: dto.rating ?? null } : {}),
      ...(dto.year !== undefined ? { year: dto.year ?? null } : {}),
    })
    return this.collectionRepository.save(item)
  }

  async remove(id: number, userId: number) {
    const item = await this.findOne(id, userId)
    await this.collectionRepository.remove(item)
    return { success: true }
  }

  /** 年度统计，附带累计数据 */
  async getStats(userId: number, year?: number) {
    const resolvedYear = year ?? new Date().getFullYear()
    const start = new Date(resolvedYear, 0, 1, 0, 0, 0, 0)
    const end = new Date(resolvedYear + 1, 0, 1, 0, 0, 0, 0)

    const [yearItems, lifetimeItems] = await Promise.all([
      this.collectionRepository.find({ where: { userId, createdAt: Between(start, end) } }),
      this.collectionRepository.find({
        where: { userId },
        select: ['id', 'type', 'status', 'rating'],
      }),
    ])

    const countType = (items: Collection[], type: CollectionType) =>
      items.filter((item) => item.type === type).length
    const averageRating = (items: Collection[]) => {
      const rated = items.filter((item) => item.rating !== null && item.rating !== undefined)
      if (!rated.length) return null
      const sum = rated.reduce((total, item) => total + Number(item.rating), 0)
      return Number((sum / rated.length).toFixed(2))
    }

    return {
      year: resolvedYear,
      total: yearItems.length,
      finished: yearItems.filter((item) => item.status === CollectionStatus.DONE).length,
      books: countType(yearItems, CollectionType.BOOK),
      movies: countType(yearItems, CollectionType.MOVIE),
      music: countType(yearItems, CollectionType.MUSIC),
      ratingAverage: averageRating(yearItems),
      lifetime: {
        total: lifetimeItems.length,
        finished: lifetimeItems.filter((item) => item.status === CollectionStatus.DONE).length,
        wish: lifetimeItems.filter((item) => item.status === CollectionStatus.WISH).length,
        doing: lifetimeItems.filter((item) => item.status === CollectionStatus.DOING).length,
        ratingAverage: averageRating(lifetimeItems),
      },
    }
  }

  /** 年度下拉的可选年份：数据里出现过的年份 + 当前年份 */
  async getYears(userId: number) {
    const rows = await this.collectionRepository
      .createQueryBuilder('collection')
      .select('DISTINCT YEAR(collection.createdAt)', 'year')
      .where('collection.userId = :userId', { userId })
      .orderBy('year', 'DESC')
      .getRawMany<{ year: number | string }>()

    const years = rows
      .map((row) => Number(row.year))
      .filter((value) => Number.isInteger(value) && value > 1970)

    const currentYear = new Date().getFullYear()
    if (!years.includes(currentYear)) years.unshift(currentYear)

    return years.sort((a, b) => b - a)
  }
}

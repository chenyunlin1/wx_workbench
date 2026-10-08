import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { Finance, FinanceType } from '../entities'
import { CreateFinanceDto } from './dto/create-finance.dto'
import { FinanceQueryDto } from './dto/finance-query.dto'
import { UpdateFinanceDto } from './dto/update-finance.dto'

@Injectable()
export class FinanceService {
  constructor(
    @InjectRepository(Finance)
    private readonly financeRepository: Repository<Finance>,
  ) {}

  async findAll(userId: number, query: FinanceQueryDto) {
    const page = Number(query.page) || 1
    const pageSize = Number(query.pageSize) || 20
    const builder = this.financeRepository
      .createQueryBuilder('finance')
      .where('finance.userId = :userId', { userId })

    if (query.type) builder.andWhere('finance.type = :type', { type: query.type })
    if (query.category) builder.andWhere('finance.category = :category', { category: query.category })
    if (query.month) {
      const { start, end } = this.getMonthRange(query.month)
      builder.andWhere('finance.recordDate >= :start AND finance.recordDate < :end', { start, end })
    }

    const [items, total] = await builder
      .orderBy('finance.recordDate', 'DESC')
      .addOrderBy('finance.id', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount()

    return { items, total, page, pageSize }
  }

  async findOne(id: number, userId: number) {
    const finance = await this.financeRepository.findOne({ where: { id, userId } })
    if (!finance) throw new NotFoundException('财务记录不存在')
    return finance
  }

  create(userId: number, dto: CreateFinanceDto) {
    return this.financeRepository.save(
      this.financeRepository.create({
        ...dto,
        remark: dto.remark?.trim() || null,
        recordDate: new Date(dto.recordDate),
        userId,
      }),
    )
  }

  async update(id: number, userId: number, dto: UpdateFinanceDto) {
    const finance = await this.findOne(id, userId)
    Object.assign(finance, {
      ...dto,
      ...(dto.recordDate ? { recordDate: new Date(dto.recordDate) } : {}),
      ...(dto.remark !== undefined ? { remark: dto.remark?.trim() || null } : {}),
    })
    return this.financeRepository.save(finance)
  }

  async remove(id: number, userId: number) {
    const finance = await this.findOne(id, userId)
    await this.financeRepository.remove(finance)
    return { success: true }
  }

  async getSummary(userId: number, month?: string) {
    const records = await this.getMonthlyRecords(userId, month)
    const income = records
      .filter((record) => record.type === FinanceType.INCOME)
      .reduce((sum, record) => sum + Number(record.amount), 0)
    const expense = records
      .filter((record) => record.type === FinanceType.EXPENSE)
      .reduce((sum, record) => sum + Number(record.amount), 0)

    return {
      month: this.resolveMonth(month),
      income: Number(income.toFixed(2)),
      expense: Number(expense.toFixed(2)),
      balance: Number((income - expense).toFixed(2)),
    }
  }

  async getStats(userId: number, month?: string) {
    const records = await this.getMonthlyRecords(userId, month)
    const summary = await this.getSummary(userId, month)
    const categoryMap = new Map<string, { category: string; income: number; expense: number }>()

    for (const record of records) {
      const current = categoryMap.get(record.category) ?? {
        category: record.category,
        income: 0,
        expense: 0,
      }
      current[record.type] += Number(record.amount)
      categoryMap.set(record.category, current)
    }

    return { ...summary, categories: Array.from(categoryMap.values()) }
  }

  async getCategories(userId: number) {
    const rows = await this.financeRepository
      .createQueryBuilder('finance')
      .select('DISTINCT finance.category', 'category')
      .where('finance.userId = :userId', { userId })
      .orderBy('finance.category', 'ASC')
      .getRawMany<{ category: string }>()

    return rows.map((row) => row.category).filter(Boolean)
  }

  private async getMonthlyRecords(userId: number, month?: string) {
    const resolvedMonth = this.resolveMonth(month)
    const { start, end } = this.getMonthRange(resolvedMonth)
    return this.financeRepository
      .createQueryBuilder('finance')
      .where('finance.userId = :userId', { userId })
      .andWhere('finance.recordDate >= :start AND finance.recordDate < :end', { start, end })
      .orderBy('finance.recordDate', 'DESC')
      .getMany()
  }

  private resolveMonth(month?: string) {
    if (month) return month
    const now = new Date()
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  }

  private getMonthRange(month: string) {
    const [year, monthNumber] = month.split('-').map(Number)
    return {
      start: new Date(year, monthNumber - 1, 1, 0, 0, 0, 0),
      end: new Date(year, monthNumber, 1, 0, 0, 0, 0),
    }
  }
}

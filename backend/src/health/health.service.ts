import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { Health } from '../entities'
import { CreateHealthDto } from './dto/create-health.dto'
import { UpdateHealthDto } from './dto/update-health.dto'

@Injectable()
export class HealthService {
  constructor(
    @InjectRepository(Health)
    private readonly healthRepository: Repository<Health>,
  ) {}

  findAll(userId: number) {
    return this.healthRepository.find({
      where: { userId },
      order: { recordDate: 'DESC' },
    })
  }

  async findOne(id: number, userId: number) {
    const record = await this.healthRepository.findOne({ where: { id, userId } })
    if (!record) throw new NotFoundException('健康记录不存在')
    return record
  }

  create(userId: number, dto: CreateHealthDto) {
    return this.healthRepository.save(this.healthRepository.create({ ...dto, userId }))
  }

  async update(id: number, userId: number, dto: UpdateHealthDto) {
    const record = await this.findOne(id, userId)
    Object.assign(record, dto)
    return this.healthRepository.save(record)
  }

  async remove(id: number, userId: number) {
    const record = await this.findOne(id, userId)
    await this.healthRepository.remove(record)
    return { success: true }
  }

  async getTrend(userId: number, limit = 7) {
    const records = await this.healthRepository.find({
      where: { userId },
      order: { recordDate: 'DESC' },
      take: limit,
    })

    const orderedRecords = records.reverse()
    const average = orderedRecords.length
      ? orderedRecords.reduce((sum, record) => sum + Number(record.weight), 0) /
        orderedRecords.length
      : null

    return {
      records: orderedRecords,
      average: average === null ? null : Number(average.toFixed(2)),
      latest: orderedRecords.at(-1) ?? null,
    }
  }
}
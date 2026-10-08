import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { Schedule, SchedulePriority } from '../entities'
import { CreateScheduleDto } from './dto/create-schedule.dto'
import { ScheduleQueryDto } from './dto/schedule-query.dto'
import { UpdateScheduleDto } from './dto/update-schedule.dto'

@Injectable()
export class SchedulesService {
  constructor(
    @InjectRepository(Schedule)
    private readonly scheduleRepository: Repository<Schedule>,
  ) {}

  findAll(userId: number, query: ScheduleQueryDto) {
    const builder = this.scheduleRepository
      .createQueryBuilder('schedule')
      .where('schedule.userId = :userId', { userId })

    if (query.start) builder.andWhere('schedule.startTime >= :start', { start: new Date(query.start) })
    if (query.end) builder.andWhere('schedule.startTime < :end', { end: new Date(query.end) })

    return builder.orderBy('schedule.startTime', 'ASC').getMany()
  }

  async findOne(id: number, userId: number) {
    const schedule = await this.scheduleRepository.findOne({ where: { id, userId } })
    if (!schedule) throw new NotFoundException('日程不存在')
    return schedule
  }

  create(userId: number, dto: CreateScheduleDto) {
    const startTime = new Date(dto.startTime)
    const endTime = dto.endTime ? new Date(dto.endTime) : new Date(startTime)
    if (endTime < startTime) throw new BadRequestException('结束时间不能早于开始时间')

    return this.scheduleRepository.save(
      this.scheduleRepository.create({
        ...dto,
        description: dto.description?.trim() || null,
        startTime,
        endTime,
        category: dto.category?.trim() || '日程',
        priority: dto.priority ?? SchedulePriority.MEDIUM,
        isRemind: dto.isRemind ?? false,
        remindBefore: dto.isRemind ? dto.remindBefore ?? 15 : null,
        userId,
      }),
    )
  }

  async update(id: number, userId: number, dto: UpdateScheduleDto) {
    const schedule = await this.findOne(id, userId)
    const startTime = dto.startTime ? new Date(dto.startTime) : schedule.startTime
    const endTime = dto.endTime
      ? new Date(dto.endTime)
      : dto.startTime
        ? new Date(startTime)
        : schedule.endTime ?? new Date(startTime)

    if (endTime < startTime) throw new BadRequestException('结束时间不能早于开始时间')

    Object.assign(schedule, {
      ...dto,
      description: dto.description !== undefined ? dto.description?.trim() || null : schedule.description,
      startTime,
      endTime,
      category: dto.category?.trim() || schedule.category,
      priority: dto.priority ?? schedule.priority,
      isRemind: dto.isRemind ?? schedule.isRemind,
      remindBefore: (dto.isRemind ?? schedule.isRemind) ? dto.remindBefore ?? schedule.remindBefore ?? 15 : null,
    })
    return this.scheduleRepository.save(schedule)
  }

  async remove(id: number, userId: number) {
    const schedule = await this.findOne(id, userId)
    await this.scheduleRepository.remove(schedule)
    return { success: true }
  }
}

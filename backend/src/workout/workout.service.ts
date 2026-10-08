import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { CreateWorkoutDto } from './dto/create-workout.dto'
import { QueryWorkoutDto } from './dto/query-workout.dto'
import { UpdateWorkoutDto } from './dto/update-workout.dto'
import { Workout, WorkoutType } from './workout.entity'

const pad = (value: number) => String(value).padStart(2, '0')
const toDateString = (date: Date) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`

@Injectable()
export class WorkoutService {
  constructor(
    @InjectRepository(Workout)
    private readonly workoutRepository: Repository<Workout>,
  ) {}

  async findAll(userId: number, query: QueryWorkoutDto) {
    const page = Number(query.page) || 1
    const pageSize = Number(query.pageSize) || 20

    const builder = this.workoutRepository
      .createQueryBuilder('workout')
      .where('workout.userId = :userId', { userId })

    if (query.type) builder.andWhere('workout.type = :type', { type: query.type })
    if (query.from) {
      builder.andWhere('workout.workoutDate >= :from', { from: new Date(`${query.from}T00:00:00`) })
    }
    if (query.to) {
      builder.andWhere('workout.workoutDate <= :to', { to: new Date(`${query.to}T23:59:59`) })
    }

    const [items, total] = await builder
      .orderBy('workout.workoutDate', 'DESC')
      .addOrderBy('workout.id', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount()

    return { items, total, page, pageSize }
  }

  async findOne(id: number, userId: number) {
    const workout = await this.workoutRepository.findOne({ where: { id, userId } })
    if (!workout) throw new NotFoundException('训练记录不存在')
    return workout
  }

  create(userId: number, dto: CreateWorkoutDto) {
    return this.workoutRepository.save(
      this.workoutRepository.create({
        type: dto.type,
        title: dto.title?.trim() || null,
        duration: dto.duration,
        calories: dto.calories ?? null,
        distance: dto.distance ?? null,
        intensity: dto.intensity,
        workoutDate: new Date(dto.workoutDate),
        note: dto.note?.trim() || null,
        userId,
      }),
    )
  }

  async update(id: number, userId: number, dto: UpdateWorkoutDto) {
    const workout = await this.findOne(id, userId)
    Object.assign(workout, {
      ...dto,
      ...(dto.workoutDate ? { workoutDate: new Date(dto.workoutDate) } : {}),
      ...(dto.title !== undefined ? { title: dto.title?.trim() || null } : {}),
      ...(dto.note !== undefined ? { note: dto.note?.trim() || null } : {}),
      ...(dto.calories !== undefined ? { calories: dto.calories ?? null } : {}),
      ...(dto.distance !== undefined ? { distance: dto.distance ?? null } : {}),
    })
    return this.workoutRepository.save(workout)
  }

  async remove(id: number, userId: number) {
    const workout = await this.findOne(id, userId)
    await this.workoutRepository.remove(workout)
    return { success: true }
  }

  /** 训练统计：窗口内汇总 + 近 N 天分布 + 类型分布 + 连续训练天数 */
  async getStats(userId: number, days = 7) {
    const now = new Date()
    const dayStart = (offset: number) =>
      new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset, 0, 0, 0, 0)

    const windowStart = dayStart(days - 1)
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0)

    const all = await this.workoutRepository.find({
      where: { userId },
      order: { workoutDate: 'DESC' },
    })

    const inWindow = all.filter((item) => item.workoutDate >= windowStart)
    const inMonth = all.filter((item) => item.workoutDate >= monthStart)

    const summarize = (items: Workout[]) => ({
      sessions: items.length,
      duration: items.reduce((sum, item) => sum + item.duration, 0),
      calories: items.reduce((sum, item) => sum + Number(item.calories ?? 0), 0),
      distance: Number(
        items.reduce((sum, item) => sum + Number(item.distance ?? 0), 0).toFixed(2),
      ),
    })

    const daily = Array.from({ length: days }, (_value, index) => {
      const date = toDateString(dayStart(days - 1 - index))
      const items = all.filter((item) => toDateString(item.workoutDate) === date)
      return { date, ...summarize(items) }
    })

    const byType = Object.values(WorkoutType)
      .map((type) => ({ type, ...summarize(inWindow.filter((item) => item.type === type)) }))
      .filter((item) => item.sessions > 0)
      .sort((a, b) => b.duration - a.duration)

    // 连续训练：从今天（今天没练则从昨天）往前数
    const trainedDates = new Set(all.map((item) => toDateString(item.workoutDate)))
    let streakDays = 0
    let cursor = 0
    if (!trainedDates.has(toDateString(now))) cursor = 1
    for (; cursor < 400; cursor += 1) {
      if (!trainedDates.has(toDateString(dayStart(cursor)))) break
      streakDays += 1
    }

    const windowSummary = summarize(inWindow)

    return {
      days,
      range: { from: toDateString(windowStart), to: toDateString(now) },
      ...windowSummary,
      averageDuration: inWindow.length ? Math.round(windowSummary.duration / inWindow.length) : 0,
      streakDays,
      daily,
      byType,
      month: summarize(inMonth),
      lifetime: summarize(all),
    }
  }
}

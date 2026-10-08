import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Between, In, Repository } from 'typeorm'
import { Habit, HabitRecord } from '../entities'
import { CreateHabitDto } from './dto/create-habit.dto'
import { UpdateHabitDto } from './dto/update-habit.dto'

const toDateString = (date = new Date()) => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

@Injectable()
export class HabitsService {
  constructor(
    @InjectRepository(Habit)
    private readonly habitRepository: Repository<Habit>,
    @InjectRepository(HabitRecord)
    private readonly recordRepository: Repository<HabitRecord>,
  ) {}

  async findAll(userId: number) {
    const habits = await this.habitRepository.find({
      where: { userId },
      order: { id: 'DESC' },
    })
    if (!habits.length) return []

    const today = toDateString()
    const records = await this.recordRepository.find({
      where: {
        habitId: In(habits.map((habit) => habit.id)),
        checkInDate: today,
      },
    })
    const checkedIds = new Set(records.map((record) => record.habitId))

    return habits.map((habit) => ({
      ...habit,
      checkedToday: checkedIds.has(habit.id),
    }))
  }

  async findOne(id: number, userId: number) {
    const habit = await this.habitRepository.findOne({ where: { id, userId } })
    if (!habit) throw new NotFoundException('习惯不存在')

    const record = await this.recordRepository.findOne({
      where: { habitId: id, checkInDate: toDateString() },
    })
    return { ...habit, checkedToday: Boolean(record) }
  }

  create(userId: number, dto: CreateHabitDto) {
    const habit = this.habitRepository.create({ ...dto, userId })
    return this.habitRepository.save(habit)
  }

  async update(id: number, userId: number, dto: UpdateHabitDto) {
    const habit = await this.habitRepository.findOne({ where: { id, userId } })
    if (!habit) throw new NotFoundException('习惯不存在')

    Object.assign(habit, dto)
    return this.habitRepository.save(habit)
  }

  async checkIn(id: number, userId: number) {
    const habit = await this.habitRepository.findOne({ where: { id, userId } })
    if (!habit) throw new NotFoundException('习惯不存在')

    const checkInDate = toDateString()
    let record = await this.recordRepository.findOne({ where: { habitId: id, checkInDate } })

    if (!record) {
      record = await this.recordRepository.save(
        this.recordRepository.create({ habitId: id, checkInDate }),
      )
      habit.streakDays += 1
      await this.habitRepository.save(habit)
    }

    return { record, streakDays: habit.streakDays, checkedToday: true }
  }

  /** 取消今日打卡，并回退连续天数 */
  async cancelCheckIn(id: number, userId: number) {
    const habit = await this.habitRepository.findOne({ where: { id, userId } })
    if (!habit) throw new NotFoundException('习惯不存在')

    const checkInDate = toDateString()
    const record = await this.recordRepository.findOne({ where: { habitId: id, checkInDate } })

    if (record) {
      await this.recordRepository.remove(record)
      habit.streakDays = Math.max(0, habit.streakDays - 1)
      await this.habitRepository.save(habit)
    }

    return { streakDays: habit.streakDays, checkedToday: false }
  }

  /** 指定日期范围内的打卡记录（用于周视图与热力图） */
  async getRecords(userId: number, start?: string, end?: string) {
    const habits = await this.habitRepository.find({ where: { userId } })
    if (!habits.length) return { records: [], habits: [] }

    const resolvedEnd = end ?? toDateString()
    const endDate = new Date(`${resolvedEnd}T00:00:00`)
    const resolvedStart =
      start ?? toDateString(new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate() - 13))

    const records = await this.recordRepository.find({
      where: {
        habitId: In(habits.map((habit) => habit.id)),
        checkInDate: Between(resolvedStart, resolvedEnd),
      },
      order: { checkInDate: 'ASC' },
    })

    return { start: resolvedStart, end: resolvedEnd, records, habits }
  }

  /** 打卡统计：今日完成率、近 N 天分布、每个习惯的最近 7 天与完成率 */
  async getStats(userId: number, days = 14) {
    const windowDays = Math.min(Math.max(Number(days) || 14, 7), 90)
    const now = new Date()
    const dayStart = (offset: number) =>
      new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset)
    const dates = Array.from({ length: windowDays }, (_value, index) =>
      toDateString(dayStart(windowDays - 1 - index)),
    )
    const today = toDateString(now)
    const habits = await this.habitRepository.find({ where: { userId }, order: { id: 'DESC' } })

    if (!habits.length) {
      return {
        days: windowDays,
        today: { total: 0, checked: 0, rate: 0 },
        week: { checked: 0, possible: 0, rate: 0 },
        longestStreak: 0,
        totalChecked: 0,
        dates,
        daily: dates.map((date) => ({ date, count: 0 })),
        habits: [],
      }
    }

    const records = await this.recordRepository.find({
      where: {
        habitId: In(habits.map((habit) => habit.id)),
        checkInDate: Between(dates[0], today),
      },
    })

    const byHabit = new Map<number, Set<string>>()
    const dailyCount = new Map<string, number>()
    let totalChecked = 0

    for (const record of records) {
      const date = String(record.checkInDate).slice(0, 10)
      if (!byHabit.has(record.habitId)) byHabit.set(record.habitId, new Set())
      byHabit.get(record.habitId)!.add(date)
      dailyCount.set(date, (dailyCount.get(date) ?? 0) + 1)
      totalChecked += 1
    }

    const weekDates = dates.slice(-7)
    const habitStats = habits.map((habit) => {
      const checkedDates = byHabit.get(habit.id) ?? new Set<string>()
      const recent = weekDates.map((date) => ({ date, checked: checkedDates.has(date) }))
      const weekCount = recent.filter((item) => item.checked).length
      return {
        id: habit.id,
        name: habit.name,
        icon: habit.icon,
        streakDays: habit.streakDays,
        checkedToday: checkedDates.has(today),
        weekCount,
        rate: Math.round((weekCount / weekDates.length) * 100),
        recent,
      }
    })

    const checkedToday = habitStats.filter((habit) => habit.checkedToday).length
    const weekChecked = weekDates.reduce((sum, date) => sum + (dailyCount.get(date) ?? 0), 0)
    const weekPossible = habits.length * weekDates.length

    return {
      days: windowDays,
      today: {
        total: habits.length,
        checked: checkedToday,
        rate: Math.round((checkedToday / habits.length) * 100),
      },
      week: {
        checked: weekChecked,
        possible: weekPossible,
        rate: weekPossible ? Math.round((weekChecked / weekPossible) * 100) : 0,
      },
      longestStreak: habits.reduce((max, habit) => Math.max(max, habit.streakDays), 0),
      totalChecked,
      dates,
      daily: dates.map((date) => ({ date, count: dailyCount.get(date) ?? 0 })),
      habits: habitStats,
    }
  }

  async remove(id: number, userId: number) {
    const habit = await this.habitRepository.findOne({ where: { id, userId } })
    if (!habit) throw new NotFoundException('习惯不存在')
    await this.habitRepository.remove(habit)
    return { success: true }
  }
}

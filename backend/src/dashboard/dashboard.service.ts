import { Injectable } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Between, In, MoreThanOrEqual, Repository } from 'typeorm'
import {
  Finance,
  FinanceType,
  Habit,
  HabitRecord,
  Health,
  Interview,
  LearningStatus,
  LearningTask,
  Schedule,
  ShoppingItem,
  ShoppingStatus,
} from '../entities'

const pad = (value: number) => String(value).padStart(2, '0')

const toDateString = (date: Date) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`

@Injectable()
export class DashboardService {
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
  ) {}

  async getSummary(userId: number) {
    const now = new Date()
    const today = toDateString(now)
    const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999)

    const [schedules, habits, learningTasks, interviews, finances, healthRecords, shopping] =
      await Promise.all([
        this.scheduleRepository.find({
          where: { userId, startTime: Between(todayStart, tomorrow) },
          order: { startTime: 'ASC' },
          take: 8,
        }),
        this.habitRepository.find({ where: { userId }, order: { id: 'DESC' }, take: 8 }),
        this.learningTaskRepository.find({ where: { userId }, order: { id: 'DESC' }, take: 6 }),
        this.interviewRepository.find({
          where: { userId, interviewTime: MoreThanOrEqual(now) },
          order: { interviewTime: 'ASC' },
          take: 5,
        }),
        this.financeRepository.find({
          where: { userId, recordDate: Between(monthStart, monthEnd) },
          order: { recordDate: 'DESC' },
        }),
        this.healthRepository.find({
          where: { userId },
          order: { recordDate: 'DESC' },
          take: 7,
        }),
        this.shoppingRepository.find({
          where: { userId, status: ShoppingStatus.PENDING },
          order: { id: 'DESC' },
          take: 6,
        }),
      ])

    const habitRecords = habits.length
      ? await this.habitRecordRepository.find({
          where: { habitId: In(habits.map((habit) => habit.id)), checkInDate: today },
        })
      : []
    const checkedHabitIds = new Set(habitRecords.map((record) => record.habitId))

    const income = finances
      .filter((record) => record.type === FinanceType.INCOME)
      .reduce((sum, record) => sum + Number(record.amount), 0)
    const expense = finances
      .filter((record) => record.type === FinanceType.EXPENSE)
      .reduce((sum, record) => sum + Number(record.amount), 0)

    const orderedHealth = [...healthRecords].reverse()
    const sevenDayAverage = orderedHealth.length
      ? orderedHealth.reduce((sum, record) => sum + Number(record.weight), 0) / orderedHealth.length
      : null

    return {
      date: today,
      schedules,
      habits: habits.map((habit) => ({
        ...habit,
        checkedToday: checkedHabitIds.has(habit.id),
      })),
      learning: {
        todayDuration: learningTasks
          .filter((task) => task.status === LearningStatus.DONE)
          .reduce((sum, task) => sum + task.duration, 0),
        tasks: learningTasks,
      },
      interviews,
      finance: {
        income: Number(income.toFixed(2)),
        expense: Number(expense.toFixed(2)),
        balance: Number((income - expense).toFixed(2)),
      },
      health: {
        latestWeight: orderedHealth.at(-1)?.weight ?? null,
        sevenDayAverage:
          sevenDayAverage === null ? null : Number(sevenDayAverage.toFixed(1)),
        records: orderedHealth,
      },
      shopping,
    }
  }
}
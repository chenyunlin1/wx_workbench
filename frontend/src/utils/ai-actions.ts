import { checkInHabit, createHabit, listHabits } from '@/api/habits'
import { createCollection } from '@/api/collection'
import { createFinance } from '@/api/finance'
import { createHealth } from '@/api/health'
import { createKnowledge } from '@/api/knowledge'
import { createSchedule } from '@/api/schedule'
import { createShoppingItem } from '@/api/shopping'
import { createWorkout } from '@/api/workout'
import type {
  AiActionField,
  CollectionPayload,
  CollectionStatus,
  CollectionType,
  FinanceFormPayload,
  HealthPayload,
  KnowledgePayload,
  KnowledgeType,
  ScheduleFormPayload,
  SchedulePriority,
  ShoppingPayload,
  WorkoutIntensity,
  WorkoutPayload,
  WorkoutType,
} from '@/types'

type Args = Record<string, unknown>

const asText = (value: unknown) => (typeof value === 'string' && value.trim() ? value.trim() : undefined)
const asNumber = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? value : undefined)
const asFlag = (value: unknown) => (typeof value === 'boolean' ? value : undefined)
const asList = (value: unknown) =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : undefined

/**
 * 网页端能一键创建的工具。请求里带上这份名单，模型就只会看到网页端可以执行的操作，
 * 不会出现「点了确认却没有对应接口」的卡片。面试 / 学习任务只有鸿蒙端有页面，由 app 自行声明。
 */
export const AI_TOOL_NAMES = [
  'create_schedule',
  'create_finance_record',
  'check_in_habit',
  'create_habit',
  'create_shopping_item',
  'create_knowledge_note',
  'create_workout_record',
  'create_health_weight',
  'create_collection_item',
]

/** 执行一次操作，返回展示给用户的成功文案 */
const runners: Record<string, (args: Args) => Promise<string>> = {
  create_schedule: async (args) => {
    const payload: ScheduleFormPayload = {
      title: asText(args.title) ?? '',
      description: asText(args.description),
      startTime: asText(args.startTime) ?? '',
      endTime: asText(args.endTime),
      category: asText(args.category) ?? '日程',
      priority: (asText(args.priority) as SchedulePriority) ?? 'medium',
      isRemind: asFlag(args.isRemind) ?? false,
      remindBefore: asNumber(args.remindBefore),
    }
    await createSchedule(payload)
    return '日程已创建'
  },

  create_finance_record: async (args) => {
    const payload: FinanceFormPayload = {
      type: (asText(args.type) as FinanceFormPayload['type']) ?? 'expense',
      amount: asNumber(args.amount) ?? 0,
      category: asText(args.category) ?? '其他',
      remark: asText(args.remark),
      recordDate: asText(args.recordDate) ?? '',
    }
    await createFinance(payload)
    return '已记账'
  },

  check_in_habit: async (args) => {
    const name = asText(args.habitName)
    if (!name) throw new Error('缺少习惯名称')
    const habits = await listHabits()
    const habit = habits.find((item) => item.name === name) ?? habits.find((item) => item.name.includes(name))
    if (!habit) throw new Error(`没有找到习惯「${name}」`)
    const result = await checkInHabit(habit.id)
    return `「${habit.name}」打卡成功，连续 ${result.streakDays} 天`
  },

  create_habit: async (args) => {
    await createHabit({
      name: asText(args.name) ?? '',
      icon: asText(args.icon),
      streakDays: asNumber(args.streakDays),
    })
    return '习惯已创建'
  },

  create_shopping_item: async (args) => {
    const payload: ShoppingPayload = {
      name: asText(args.name) ?? '',
      price: asNumber(args.price),
    }
    await createShoppingItem(payload)
    return '已加入待买清单'
  },

  create_knowledge_note: async (args) => {
    const payload: KnowledgePayload & { type: KnowledgeType; title: string; content: string } = {
      type: (asText(args.type) as KnowledgeType) ?? 'note',
      title: asText(args.title) ?? '',
      content: asText(args.content) ?? '',
      tags: asList(args.tags),
    }
    await createKnowledge(payload)
    return '知识记录已保存'
  },

  create_workout_record: async (args) => {
    const payload: WorkoutPayload = {
      type: (asText(args.type) as WorkoutType) ?? 'other',
      title: asText(args.title),
      duration: asNumber(args.duration) ?? 0,
      calories: asNumber(args.calories),
      distance: asNumber(args.distance),
      intensity: (asText(args.intensity) as WorkoutIntensity) ?? 'medium',
      workoutDate: asText(args.workoutDate) ?? '',
      note: asText(args.note),
    }
    await createWorkout(payload)
    return '训练已记录'
  },

  create_health_weight: async (args) => {
    const payload: HealthPayload = {
      weight: asNumber(args.weight) ?? 0,
      recordDate: asText(args.recordDate) ?? '',
    }
    await createHealth(payload)
    return '体重已记录'
  },

  create_collection_item: async (args) => {
    const payload: CollectionPayload = {
      type: (asText(args.type) as CollectionType) ?? 'book',
      title: asText(args.title) ?? '',
      status: (asText(args.status) as CollectionStatus) ?? 'wish',
      rating: asNumber(args.rating),
      year: asNumber(args.year),
      comment: asText(args.comment),
    }
    await createCollection(payload)
    return '已加入书影音收藏'
  },
}

export const supportsAiAction = (tool: string) => Boolean(runners[tool])

export const runAiAction = async (tool: string, args: Args): Promise<string> => {
  const runner = runners[tool]
  if (!runner) throw new Error(`当前端暂不支持 ${tool}`)
  return runner(args)
}

/** 卡片上「创建后跳转到对应模块」的提示，取自后端已经算好的展示字段 */
export const describeActionFields = (fields: AiActionField[]) =>
  fields.map((field) => `${field.label}：${field.value}`).join('　')

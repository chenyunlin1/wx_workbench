import { Api, HabitPayload, HealthPayload, LearningPayload } from '../api/Api'
import {
  CollectionPayload,
  FinancePayload,
  InterviewPayload,
  KnowledgePayload,
  SchedulePayload,
  WorkoutPayload
} from '../model/Models'

/**
 * AI 工具在鸿蒙端的执行器。后端只把模型的工具调用校验成「待确认操作」，
 * 这里负责用 app 自己的创建接口真正写入，所以 app 可以声明网页端没有的面试 / 学习任务。
 */
export const AI_TOOL_NAMES: string[] = [
  'create_schedule',
  'create_finance_record',
  'check_in_habit',
  'create_habit',
  'create_shopping_item',
  'create_knowledge_note',
  'create_learning_task',
  'create_workout_record',
  'create_health_weight',
  'create_collection_item',
  'create_interview'
]

function argText(args: Record<string, Object>, key: string): string {
  const value = args[key]
  if (value === undefined || value === null) {
    return ''
  }
  return value.toString()
}

function argNumber(args: Record<string, Object>, key: string): number {
  const text = argText(args, key)
  if (text.length === 0) {
    return 0
  }
  const parsed = parseFloat(text)
  return Number.isNaN(parsed) ? 0 : parsed
}

function argFlag(args: Record<string, Object>, key: string): boolean {
  return argText(args, key) === 'true'
}

function hasArg(args: Record<string, Object>, key: string): boolean {
  const value = args[key]
  return value !== undefined && value !== null && value.toString().length > 0
}

function orFallback(text: string, fallback: string): string {
  return text.length > 0 ? text : fallback
}

function required(text: string, label: string): string {
  if (text.length === 0) {
    throw new Error('缺少' + label)
  }
  return text
}

export function actionStateLabel(status: string): string {
  switch (status) {
    case 'done':
      return '已创建'
    case 'failed':
      return '创建失败'
    case 'cancelled':
      return '已取消'
    default:
      return '待确认'
  }
}

/** 执行一次操作，返回展示给用户的成功文案；失败以异常抛出 */
export async function runAiAction(tool: string, args: Record<string, Object>): Promise<string> {
  switch (tool) {
    case 'create_schedule': {
      const payload: SchedulePayload = {
        title: required(argText(args, 'title'), '日程标题'),
        startTime: required(argText(args, 'startTime'), '开始时间'),
        category: orFallback(argText(args, 'category'), '日程'),
        priority: orFallback(argText(args, 'priority'), 'medium'),
        isRemind: argFlag(args, 'isRemind')
      }
      if (hasArg(args, 'description')) {
        payload.description = argText(args, 'description')
      }
      if (hasArg(args, 'endTime')) {
        payload.endTime = argText(args, 'endTime')
      }
      if (hasArg(args, 'remindBefore')) {
        payload.remindBefore = argNumber(args, 'remindBefore')
      }
      await Api.createSchedule(payload)
      return '日程已创建'
    }

    case 'create_finance_record': {
      const amount = argNumber(args, 'amount')
      if (amount <= 0) {
        throw new Error('金额无效')
      }
      const payload: FinancePayload = {
        type: orFallback(argText(args, 'type'), 'expense'),
        amount: amount,
        category: orFallback(argText(args, 'category'), '其他'),
        recordDate: required(argText(args, 'recordDate'), '日期')
      }
      if (hasArg(args, 'remark')) {
        payload.remark = argText(args, 'remark')
      }
      await Api.createFinance(payload)
      return '已记账'
    }

    case 'check_in_habit': {
      const name = required(argText(args, 'habitName'), '习惯名称')
      const habits = await Api.listHabits()
      let targetId = 0
      for (const item of habits) {
        if (item.name === name) {
          targetId = item.id
          break
        }
      }
      if (targetId === 0) {
        for (const item of habits) {
          if (item.name.indexOf(name) >= 0) {
            targetId = item.id
            break
          }
        }
      }
      if (targetId === 0) {
        throw new Error('没有找到习惯「' + name + '」')
      }
      const result = await Api.checkInHabit(targetId)
      return '「' + name + '」打卡成功，连续 ' + result.streakDays + ' 天'
    }

    case 'create_habit': {
      const payload: HabitPayload = {
        name: required(argText(args, 'name'), '习惯名称'),
        icon: orFallback(argText(args, 'icon'), '🎯')
      }
      await Api.createHabit(payload)
      return '习惯已创建'
    }

    case 'create_shopping_item': {
      const name = required(argText(args, 'name'), '商品名称')
      await Api.createShopping(name, hasArg(args, 'price') ? argNumber(args, 'price') : 0)
      return '已加入待买清单'
    }

    case 'create_knowledge_note': {
      const payload: KnowledgePayload = {
        type: orFallback(argText(args, 'type'), 'note'),
        title: required(argText(args, 'title'), '标题'),
        content: required(argText(args, 'content'), '内容')
      }
      const tags = argText(args, 'tags')
      if (tags.length > 0) {
        payload.tags = tags.split(',')
      }
      await Api.createKnowledge(payload)
      return '知识记录已保存'
    }

    case 'create_learning_task': {
      const payload: LearningPayload = {
        title: required(argText(args, 'title'), '任务名称'),
        duration: argNumber(args, 'duration'),
        status: orFallback(argText(args, 'status'), 'todo')
      }
      await Api.createLearning(payload)
      return '学习任务已创建'
    }

    case 'create_workout_record': {
      const payload: WorkoutPayload = {
        type: orFallback(argText(args, 'type'), 'other'),
        duration: argNumber(args, 'duration'),
        intensity: orFallback(argText(args, 'intensity'), 'medium'),
        workoutDate: required(argText(args, 'workoutDate'), '训练时间')
      }
      if (hasArg(args, 'title')) {
        payload.title = argText(args, 'title')
      }
      if (hasArg(args, 'calories')) {
        payload.calories = argNumber(args, 'calories')
      }
      if (hasArg(args, 'distance')) {
        payload.distance = argNumber(args, 'distance')
      }
      if (hasArg(args, 'note')) {
        payload.note = argText(args, 'note')
      }
      await Api.createWorkout(payload)
      return '训练已记录'
    }

    case 'create_health_weight': {
      const weight = argNumber(args, 'weight')
      if (weight <= 0) {
        throw new Error('体重无效')
      }
      const payload: HealthPayload = {
        weight: weight,
        recordDate: required(argText(args, 'recordDate'), '日期')
      }
      await Api.createHealth(payload)
      return '体重已记录'
    }

    case 'create_collection_item': {
      const payload: CollectionPayload = {
        type: orFallback(argText(args, 'type'), 'book'),
        title: required(argText(args, 'title'), '名称'),
        status: orFallback(argText(args, 'status'), 'wish')
      }
      if (hasArg(args, 'rating')) {
        payload.rating = argNumber(args, 'rating')
      }
      if (hasArg(args, 'year')) {
        payload.year = argNumber(args, 'year')
      }
      if (hasArg(args, 'comment')) {
        payload.comment = argText(args, 'comment')
      }
      await Api.createCollection(payload)
      return '已加入书影音收藏'
    }

    case 'create_interview': {
      const payload: InterviewPayload = {
        company: required(argText(args, 'company'), '公司'),
        position: required(argText(args, 'position'), '岗位'),
        interviewTime: required(argText(args, 'interviewTime'), '面试时间'),
        status: orFallback(argText(args, 'status'), 'pending')
      }
      await Api.createInterview(payload)
      return '面试已记录'
    }

    default:
      throw new Error('本机暂不支持 ' + tool)
  }
}

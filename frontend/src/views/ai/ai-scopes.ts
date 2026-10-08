import type { AiContextScope } from '@/types'

/** AI 助手可读取的平台数据范围，与后端 ai.constants.ts 的 AI_CONTEXT_SCOPES 保持一致 */
export const AI_SCOPE_OPTIONS: Array<{ value: AiContextScope; label: string; hint: string }> = [
  { value: 'schedules', label: '日程安排', hint: '今日与未来 7 天' },
  { value: 'habits', label: '习惯打卡', hint: '连续天数与今日状态' },
  { value: 'learning', label: '学习任务', hint: '状态与时长' },
  { value: 'knowledge', label: '学习知识库', hint: '标题、标签与摘要' },
  { value: 'collections', label: '书影音收藏', hint: '状态与评分、短评' },
  { value: 'interviews', label: '面试安排', hint: '待进行的面试' },
  { value: 'finance', label: '记账财务', hint: '本月收支与分类' },
  { value: 'health', label: '健康体重', hint: '最近 10 次记录' },
  { value: 'workouts', label: '健身训练', hint: '近 7 天训练量与类型' },
  { value: 'shopping', label: '待买清单', hint: '未购买条目' },
]

import type { WorkoutIntensity, WorkoutType } from '@/types'

export type WorkoutTone = 'blue' | 'violet' | 'green' | 'teal' | 'rose' | 'orange'

export interface WorkoutTypeMeta {
  value: WorkoutType
  label: string
  emoji: string
  tone: WorkoutTone
}

export const WORKOUT_TYPES: WorkoutTypeMeta[] = [
  { value: 'running', label: '跑步', emoji: '🏃', tone: 'blue' },
  { value: 'strength', label: '力量', emoji: '🏋️', tone: 'violet' },
  { value: 'cycling', label: '骑行', emoji: '🚴', tone: 'green' },
  { value: 'swimming', label: '游泳', emoji: '🏊', tone: 'teal' },
  { value: 'yoga', label: '瑜伽', emoji: '🧘', tone: 'rose' },
  { value: 'hiit', label: 'HIIT', emoji: '⚡', tone: 'orange' },
  { value: 'walking', label: '快走', emoji: '🚶', tone: 'blue' },
  { value: 'other', label: '其他', emoji: '🤸', tone: 'violet' },
]

export const INTENSITY_OPTIONS: Array<{ value: WorkoutIntensity; label: string }> = [
  { value: 'low', label: '低强度' },
  { value: 'medium', label: '中等强度' },
  { value: 'high', label: '高强度' },
]

export const workoutMeta = (type: WorkoutType): WorkoutTypeMeta =>
  WORKOUT_TYPES.find((item) => item.value === type) ?? WORKOUT_TYPES[WORKOUT_TYPES.length - 1]

export const intensityLabel = (intensity: WorkoutIntensity) =>
  INTENSITY_OPTIONS.find((item) => item.value === intensity)?.label ?? '中等强度'

export const WINDOW_OPTIONS = [
  { value: 7, label: '近 7 天' },
  { value: 14, label: '近 14 天' },
  { value: 30, label: '近 30 天' },
] as const

import type { CorosSportCategory, Workout } from '@/types'

/** 每公里用时（秒）；没有距离就没法算配速 */
export const paceSeconds = (workout: Workout) =>
  Number(workout.distance) > 0 ? (workout.duration * 60) / Number(workout.distance) : 0

/** 配速按跑步的书写习惯显示成 5分32秒 */
export const formatPace = (seconds: number) => {
  if (!Number.isFinite(seconds) || seconds <= 0) return '—'
  const minutes = Math.floor(seconds / 60)
  const rest = Math.round(seconds % 60)
  return `${minutes}分${String(rest).padStart(2, '0')}秒`
}

/** 秒 → 高驰那种 h:mm:ss / mm:ss，成绩预测用 */
export const formatDuration = (seconds: number | null) => {
  if (!seconds || !Number.isFinite(seconds)) return '—'
  const total = Math.round(seconds)
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  const pad = (value: number) => String(value).padStart(2, '0')
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`
}

/** 分钟 → 「7小时20分钟」，睡眠与运动时长用 */
export const formatMinutes = (minutes: number | null) => {
  if (minutes === null || !Number.isFinite(minutes) || minutes <= 0) return '—'
  const h = Math.floor(minutes / 60)
  const m = Math.round(minutes % 60)
  return h > 0 ? `${h}小时${m ? `${m}分钟` : ''}` : `${m}分钟`
}

/** 高驰的英文状态词翻成界面用语，未登录/没有数据时会原样落回 null */
const LOAD_COMMENTS: Record<string, string> = {
  Performance: '竞技状态',
  Optimized: '训练最佳',
  Maintaining: '保持稳定',
  Declining: '正在下降',
  Excessive: '训练过度',
  Recovery: '恢复中',
  Basic: '基础训练',
}

export const loadCommentOf = (comment: string | null) =>
  comment ? LOAD_COMMENTS[comment] ?? comment : null

/** 训练负荷比值的配色：最佳区间绿色，过高红色 */
export const loadToneOf = (comment: string | null): 'ok' | 'warn' | 'bad' | 'muted' => {
  if (!comment) return 'muted'
  if (comment === 'Excessive') return 'bad'
  if (comment === 'Optimized' || comment === 'Performance') return 'ok'
  if (comment === 'Declining') return 'warn'
  return 'muted'
}

const RECOVERY_LEVELS: Record<string, string> = {
  'Heavy training allowed': '可以进行大强度训练',
  'Light training allowed': '适合轻量训练',
  'Fully recovered': '已完全恢复',
  'Fatigue': '疲劳',
}

export const recoveryLevelOf = (level: string | null) =>
  level ? RECOVERY_LEVELS[level] ?? level : null

const SPORT_NAMES: Record<string, string> = {
  'Outdoor Run': '户外跑步',
  'Indoor Run': '室内跑步',
  'Trail Run': '越野跑',
  'Treadmill': '跑步机',
  'Outdoor Bike': '户外骑行',
  'Indoor Bike': '室内骑行',
  'Pool Swim': '泳池游泳',
  'Open Water Swim': '开放水域游泳',
  Strength: '力量训练',
  'Strength Training': '力量训练',
}

export const sportNameOf = (name: string | null) =>
  name ? SPORT_NAMES[name] ?? name : '运动'

/** 成绩预测的赛程名：高驰给英文，界面用中文距离说法 */
export const predictionLabelOf = (label: string) =>
  label
    .replace('Half Marathon', '半程马拉松')
    .replace('Marathon', '全程马拉松')
    .replace(/(\d+)\s*km/, '$1 公里')

export const CATEGORY_LABELS: Record<CorosSportCategory, string> = {
  running: '跑步',
  cycling: '骑行',
  swimming: '游泳',
  strength: '力量',
  other: '其他',
}

export const CATEGORY_EMOJI: Record<CorosSportCategory, string> = {
  running: '🏃',
  cycling: '🚴',
  swimming: '🏊',
  strength: '🏋️',
  other: '🎯',
}

export const RUNNING_QUESTIONS = [
  '我这一周在高驰上总共跑了多少公里？平均配速是多少',
  '最近一次长距离跑的配速和心率表现怎么样',
  '结合我昨晚的睡眠和今天的恢复程度，适合安排间歇跑还是轻松跑',
  '我这周的 HRV 和静息心率有变化吗？说明了什么',
  '根据高驰的跑量趋势，帮我规划下周的三次跑步，并把时间排进日程',
]

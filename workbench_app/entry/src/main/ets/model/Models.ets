/**
 * 与 LifeOS 后端接口对应的数据模型。
 * 枚举类字段统一用 string，避免 ArkTS 字面量联合类型在赋值处的限制。
 */

export interface User {
  id: number
  username: string
  avatar?: string | null
  role: string
  createdAt?: string
}

export interface LoginResult {
  accessToken: string
  user: User
}

/* ---------------- 日程 ---------------- */

export interface Schedule {
  id: number
  title: string
  description?: string | null
  startTime: string
  endTime?: string | null
  category: string
  priority: string
  isRemind: boolean
  remindBefore?: number | null
  completed: boolean
  createdAt?: string
  updatedAt?: string
}

export interface SchedulePayload {
  title: string
  description?: string
  startTime: string
  endTime?: string
  category: string
  priority: string
  isRemind: boolean
  remindBefore?: number
  completed?: boolean
}

/* ---------------- 习惯 / 健康 ---------------- */

export interface Habit {
  id: number
  name: string
  icon: string
  streakDays: number
  checkedToday: boolean
}

export interface HabitCheckInResult {
  streakDays: number
  checkedToday: boolean
}

export interface HabitRecentDay {
  date: string
  checked: boolean
}

export interface HabitStatItem {
  id: number
  name: string
  icon: string
  streakDays: number
  checkedToday: boolean
  weekCount: number
  rate: number
  recent: HabitRecentDay[]
}

export interface HabitStats {
  days: number
  today: CountStat
  week: WeekStat
  longestStreak: number
  totalChecked: number
  dates?: string[]
  daily: DayCount[]
  habits: HabitStatItem[]
}

export interface CountStat {
  total: number
  checked: number
  rate: number
}

export interface WeekStat {
  checked: number
  possible: number
  rate: number
}

export interface DayCount {
  date: string
  count: number
}

export interface WeightRecord {
  id: number
  weight: number
  recordDate: string
}

export interface HealthTrend {
  records: WeightRecord[]
  average?: number | null
  latest?: WeightRecord | null
}

/* ---------------- 学习 ---------------- */

export interface LearningTask {
  id: number
  title: string
  duration: number
  status: string
}

/* ---------------- 面试 ---------------- */

export interface Interview {
  id: number
  company: string
  position: string
  interviewTime: string
  status: string
}

export interface InterviewPayload {
  company: string
  position: string
  interviewTime: string
  status: string
}

/* ---------------- 财务 ---------------- */

export interface Finance {
  id: number
  type: string
  amount: number
  category: string
  remark?: string | null
  recordDate: string
  createdAt?: string
  updatedAt?: string
}

export interface FinanceListResult {
  items: Finance[]
  total: number
  page: number
  pageSize: number
}

export interface FinanceSummary {
  month: string
  income: number
  expense: number
  balance: number
}

export interface FinancePayload {
  type: string
  amount: number
  category: string
  remark?: string
  recordDate: string
}

/* ---------------- 健身 ---------------- */

export interface Workout {
  id: number
  type: string
  title?: string | null
  duration: number
  calories?: number | null
  distance?: number | null
  intensity: string
  workoutDate: string
  note?: string | null
  createdAt?: string
  updatedAt?: string
}

export interface WorkoutPayload {
  type: string
  title?: string
  duration: number
  calories?: number | null
  distance?: number | null
  intensity?: string
  workoutDate: string
  note?: string | null
}

export interface WorkoutSummary {
  sessions: number
  duration: number
  calories: number
  distance: number
}

export interface WorkoutStats extends WorkoutSummary {
  days: number
  range: RangeInfo
  averageDuration: number
  streakDays: number
  daily: WorkoutDay[]
  byType: WorkoutTypeAgg[]
  month: WorkoutSummary
  lifetime: WorkoutSummary
}

export interface RangeInfo {
  from: string
  to: string
}

export interface WorkoutDay extends WorkoutSummary {
  date: string
}

export interface WorkoutTypeAgg extends WorkoutSummary {
  type: string
}

export interface WorkoutListResult {
  items: Workout[]
  total: number
  page: number
  pageSize: number
}

/* ---------------- 待买清单 ---------------- */

export interface ShoppingItem {
  id: number
  name: string
  price: number
  status: string
  createdAt?: string
}

/* ---------------- 书影音收藏 ---------------- */

export interface CollectionItem {
  id: number
  type: string
  title: string
  status: string
  rating?: number | null
  year?: number | null
  coverUrl?: string | null
  comment?: string | null
  createdAt?: string
  updatedAt?: string
}

export interface CollectionListResult {
  items: CollectionItem[]
  total: number
  page: number
  pageSize: number
}

export interface CollectionStats {
  year: number
  total: number
  finished: number
  books: number
  movies: number
  music: number
  ratingAverage?: number | null
  lifetime?: LifetimeStat
}

export interface LifetimeStat {
  total: number
  finished: number
  wish: number
  doing: number
  ratingAverage?: number | null
}

export interface CollectionPayload {
  type: string
  title: string
  status: string
  rating?: number | null
  year?: number | null
  coverUrl?: string | null
  comment?: string | null
}

/* ---------------- 知识库（备忘） ---------------- */

export interface KnowledgeItem {
  id: number
  type: string
  title: string
  content: string
  tags: string[]
  isLearned: boolean
  isPublic?: boolean
  userId?: number
  views: number
  createdAt: string
  updatedAt: string
}

export interface KnowledgeListResult {
  items: KnowledgeItem[]
  total: number
  page: number
  pageSize: number
}

export interface KnowledgePayload {
  type?: string
  title?: string
  content?: string
  tags?: string[]
  isLearned?: boolean
}

/* ---------------- 练习 ---------------- */

export interface FlashcardQuestion {
  id: number
  type: string
  title: string
  content: string
  tags: string[]
}

export interface FillblankQuestion {
  id: number
  type: string
  title: string
  options: string[]
  correctAnswer: string
  tags: string[]
}

export interface PracticeResultPayload {
  mode: string
  total: number
  remembered: number
  fuzzy: number
  forgotten: number
  duration: number
}

/* ---------------- AI ---------------- */

export interface AiSettings {
  provider: string
  baseUrl: string
  model: string
  temperature: number
  systemPrompt: string
  contextScope: string[]
  hasApiKey: boolean
  apiKeyPreview?: string | null
  keySource: string
  defaultSystemPrompt: string
  updatedAt?: string | null
}

export interface AiSettingsPayload {
  apiKey?: string
  baseUrl?: string
  model?: string
  temperature?: number
  systemPrompt?: string
  contextScope?: string[]
}

export interface AiTestResult {
  ok: boolean
  model: string
  baseUrl: string
  latencyMs: number
  message: string
  reply?: string
}

export interface AiConversationSummary {
  id: number
  title: string
  model?: string | null
  messageCount: number
  preview: string
  lastMessageAt?: string | null
  createdAt: string
  updatedAt: string
}

export interface AiConversationMessage {
  id: number
  role: string
  content: string
  error?: string | null
  createdAt: string
  actions?: AiAction[] | null
}

export interface AiConversationDetail {
  conversation: AiConversationInfo
  messages: AiConversationMessage[]
}

export interface AiConversationInfo {
  id: number
  title: string
  model?: string | null
  lastMessageAt?: string | null
  createdAt: string
  updatedAt: string
}

/** AI 提议的写操作：后端只负责校验与展示，真正入库由客户端调用各自的创建接口 */
export interface AiActionField {
  label: string
  value: string
}

export interface AiAction {
  tool: string
  label: string
  args: Record<string, Object>
  fields: AiActionField[]
  status: string
  error?: string | null
}

export interface AiChatResult {
  content: string
  model: string
  conversationId?: number | null
  conversationTitle?: string | null
  messageId?: number | null
  actions?: AiAction[] | null
}

/* ---------------- 首页聚合 ---------------- */

export interface DashboardSummary {
  date: string
  schedules: Schedule[]
  habits: Habit[]
  learning: DashLearning
  interviews: Interview[]
  finance: DashFinance
  health: DashHealth
  shopping: ShoppingItem[]
}

export interface DashLearning {
  todayDuration: number
  tasks: LearningTask[]
}

export interface DashFinance {
  income: number
  expense: number
  balance: number
}

export interface DashHealth {
  latestWeight: number | null
  sevenDayAverage: number | null
  records: WeightRecord[]
}

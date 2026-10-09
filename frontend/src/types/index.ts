export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export interface User {
  id: number
  username: string
  nickname?: string | null
  avatar?: string | null
  role: 'admin' | 'user'
  createdAt?: string
}

export type SchedulePriority = 'high' | 'medium' | 'low'

export interface Schedule {
  id: number
  title: string
  description?: string | null
  startTime: string
  endTime: string | null
  category: string
  priority: SchedulePriority
  isRemind: boolean
  remindBefore: number | null
  completed: boolean
  createdAt: string
  updatedAt: string
}

export interface ScheduleFormPayload {
  title: string
  description?: string
  startTime: string
  endTime?: string
  category: string
  priority: SchedulePriority
  isRemind: boolean
  remindBefore?: number
  completed?: boolean
}

export interface Habit {
  id: number
  name: string
  icon: string
  streakDays: number
  checkedToday: boolean
}

export interface LearningTask {
  id: number
  title: string
  duration: number
  status: 'todo' | 'doing' | 'done'
}

export interface Interview {
  id: number
  company: string
  position: string
  interviewTime: string
  status: 'pending' | 'passed' | 'rejected' | 'cancelled'
}

export interface Finance {
  id: number
  type: 'income' | 'expense'
  amount: number
  category: string
  remark: string | null
  recordDate: string
  createdAt: string
  updatedAt: string
}

export interface FinanceQuery {
  type?: 'income' | 'expense'
  category?: string
  month?: string
  page?: number
  pageSize?: number
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

export interface FinanceFormPayload {
  type: 'income' | 'expense'
  amount: number
  category: string
  remark?: string
  recordDate: string
}

export interface Health {
  id: number
  weight: number
  recordDate: string
}

export interface ShoppingItem {
  id: number
  name: string
  price: number
  status: 'pending' | 'bought'
  createdAt?: string
}

export interface DashboardSummary {
  date: string
  schedules: Schedule[]
  habits: Habit[]
  learning: {
    todayDuration: number
    tasks: LearningTask[]
  }
  interviews: Interview[]
  finance: {
    income: number
    expense: number
    balance: number
  }
  health: {
    latestWeight: number | null
    sevenDayAverage: number | null
    records: Health[]
  }
  shopping: ShoppingItem[]
}

export interface LoginResult {
  accessToken: string
  user: User
}
export type KnowledgeType = 'note' | 'qa'
export type KnowledgeSortBy = 'updatedAt' | 'createdAt' | 'views'

export interface KnowledgeItem {
  id: number
  type: KnowledgeType
  title: string
  content: string
  tags: string[]
  isLearned: boolean
  isPublic: boolean
  userId: number
  views: number
  createdAt: string
  updatedAt: string
}

export interface KnowledgeQuery {
  keyword?: string
  type?: KnowledgeType
  tag?: string
  page?: number
  pageSize?: number
  sortBy?: KnowledgeSortBy
}

export interface KnowledgeListResult {
  items: KnowledgeItem[]
  total: number
  page: number
  pageSize: number
}

export interface KnowledgePayload {
  type?: KnowledgeType
  title?: string
  content?: string
  tags?: string[]
  isLearned?: boolean
}
export type PracticeMode = 'flashcard' | 'fillblank'
export type PracticeAnswerResult = 'remembered' | 'fuzzy' | 'forgotten'

export interface FlashcardPracticeQuestion {
  id: number
  type: 'flashcard'
  title: string
  content: string
  tags: string[]
}

export interface FillblankPracticeQuestion {
  id: number
  type: 'fillblank'
  title: string
  options: string[]
  correctAnswer: string
  tags: string[]
}

export type PracticeQuestion = FlashcardPracticeQuestion | FillblankPracticeQuestion

export interface PracticeAnswer {
  questionId: number
  questionType: PracticeMode
  title: string
  tags: string[]
  result: PracticeAnswerResult
  selectedAnswer?: string
  correctAnswer?: string
}

export interface PracticeResultSummary {
  total: number
  remembered: number
  fuzzy: number
  forgotten: number
  duration: number
}

/* ---------------- 习惯与健康 ---------------- */

export interface HabitPayload {
  name: string
  icon?: string
  streakDays?: number
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
  today: { total: number; checked: number; rate: number }
  week: { checked: number; possible: number; rate: number }
  longestStreak: number
  totalChecked: number
  dates: string[]
  daily: Array<{ date: string; count: number }>
  habits: HabitStatItem[]
}

export interface HealthPayload {
  weight: number
  recordDate: string
}

export interface HealthTrend {
  records: Health[]
  average: number | null
  latest: Health | null
}

/* ---------------- 健身训练 ---------------- */

export type WorkoutType =
  | 'running'
  | 'strength'
  | 'cycling'
  | 'swimming'
  | 'yoga'
  | 'hiit'
  | 'walking'
  | 'other'

export type WorkoutIntensity = 'low' | 'medium' | 'high'

export interface Workout {
  id: number
  type: WorkoutType
  title: string | null
  duration: number
  calories: number | null
  distance: number | null
  intensity: WorkoutIntensity
  workoutDate: string
  note: string | null
  createdAt: string
  updatedAt: string
}

export interface WorkoutPayload {
  type: WorkoutType
  title?: string
  duration: number
  calories?: number | null
  distance?: number | null
  intensity?: WorkoutIntensity
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
  range: { from: string; to: string }
  averageDuration: number
  streakDays: number
  daily: Array<WorkoutSummary & { date: string }>
  byType: Array<WorkoutSummary & { type: WorkoutType }>
  month: WorkoutSummary
  lifetime: WorkoutSummary
}

export interface WorkoutListResult {
  items: Workout[]
  total: number
  page: number
  pageSize: number
}

/* ---------------- 待买清单 ---------------- */

export interface ShoppingPayload {
  name: string
  price?: number
  status?: 'pending' | 'bought'
}

/* ---------------- 书影音收藏 ---------------- */

export type CollectionType = 'book' | 'movie' | 'music'
export type CollectionStatus = 'wish' | 'doing' | 'done'

export interface CollectionItem {
  id: number
  type: CollectionType
  title: string
  status: CollectionStatus
  rating: number | null
  year: number | null
  coverUrl: string | null
  comment: string | null
  createdAt: string
  updatedAt: string
}

export interface CollectionQuery {
  type?: CollectionType
  status?: CollectionStatus
  keyword?: string
  year?: number
  page?: number
  pageSize?: number
  sortBy?: 'createdAt' | 'rating' | 'year' | 'title'
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
  ratingAverage: number | null
  lifetime: {
    total: number
    finished: number
    wish: number
    doing: number
    ratingAverage: number | null
  }
}

export interface CollectionPayload {
  type: CollectionType
  title: string
  status: CollectionStatus
  rating?: number | null
  year?: number | null
  coverUrl?: string | null
  comment?: string | null
}

/* ---------------- AI 助手 ---------------- */

export type AiContextScope =
  | 'schedules'
  | 'habits'
  | 'learning'
  | 'knowledge'
  | 'collections'
  | 'health'
  | 'workouts'
  | 'interviews'
  | 'finance'
  | 'shopping'

export type AiKeySource = 'user' | 'env' | 'none'

export interface AiSettings {
  provider: string
  baseUrl: string
  model: string
  temperature: number
  systemPrompt: string
  contextScope: AiContextScope[]
  hasApiKey: boolean
  apiKeyPreview: string | null
  keySource: AiKeySource
  defaultSystemPrompt: string
  updatedAt: string | null
}

export interface AiSettingsPayload {
  apiKey?: string
  baseUrl?: string
  model?: string
  temperature?: number
  systemPrompt?: string
  contextScope?: AiContextScope[]
}

export interface AiTestResult {
  ok: boolean
  model: string
  baseUrl: string
  latencyMs: number
  message: string
  reply?: string
}

export interface AiContextSection {
  key: AiContextScope
  title: string
  count: number
  summary: string
}

export interface AiContextSnapshot {
  generatedAt: string
  date: string
  weekday: string
  scope: AiContextScope[]
  sections: AiContextSection[]
  stats: Record<string, number>
  truncated: boolean
  length: number
  text: string
}

export interface AiChatTurn {
  role: 'user' | 'assistant'
  content: string
}

export type AiActionStatus = 'pending' | 'done' | 'failed' | 'cancelled'

export interface AiActionField {
  label: string
  value: string
}

/**
 * AI 助手提议的一次写入操作。后端只负责整理参数，真正调用创建接口的是本页客户端，
 * 所以 args 必须原样传给对应的 api 函数。
 */
export interface AiChatAction {
  tool: string
  label: string
  args: Record<string, unknown>
  fields: AiActionField[]
  status: AiActionStatus
  error: string | null
}

export interface AiChatPayload {
  conversationId?: number
  messages?: AiChatTurn[]
  content?: string
  /** 本端实现了哪些工具，后端只下发这些，避免模型提出客户端无法执行的操作 */
  toolNames?: string[]
  contextScope?: AiContextScope[]
  useContext?: boolean
  /** 关掉后本次对话不挂高驰 MCP 工具 */
  useMcp?: boolean
  temperature?: number
}

/** 服务端当场执行掉的高驰 MCP 工具，正文里的数据就来自这些调用 */
export interface AiMcpCall {
  name: string
  label: string
  ok: boolean
}

export interface AiConversationSummary {
  id: number
  title: string
  model: string | null
  messageCount: number
  preview: string
  lastMessageAt: string | null
  createdAt: string
  updatedAt: string
}

export interface AiConversationMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  reasoning: string | null
  model: string | null
  elapsedMs: number | null
  contextMeta: AiChatResult['context']
  actions: AiChatAction[] | null
  error: string | null
  createdAt: string
}

export interface AiConversationDetail {
  conversation: {
    id: number
    title: string
    model: string | null
    lastMessageAt: string | null
    createdAt: string
    updatedAt: string
  }
  messages: AiConversationMessage[]
}

export interface AiUsage {
  prompt_tokens?: number
  completion_tokens?: number
  total_tokens?: number
}

export interface AiChatResult {
  content: string
  model: string
  finishReason: string | null
  usage: AiUsage | null
  conversationId?: number | null
  conversationTitle?: string | null
  messageId?: number | null
  actions?: AiChatAction[]
  mcpCalls?: AiMcpCall[]
  context: {
    generatedAt: string
    date: string
    weekday: string
    scope: AiContextScope[]
    sections: AiContextSection[]
    stats: Record<string, number>
    length: number
    truncated: boolean
  } | null
}

export interface AiStreamMeta {
  model: string
  context: AiChatResult['context']
  conversationId?: number | null
  conversationTitle?: string | null
  /** 本次挂上的高驰 MCP 工具数量 */
  mcpTools?: number
}

export interface AiStreamDone {
  model: string
  finishReason: string | null
  usage: AiUsage | null
  elapsedMs: number
  length: number
  messageId?: number | null
  actions?: AiChatAction[]
  mcpCalls?: AiMcpCall[]
}

export type AiMessageStatus = 'streaming' | 'done' | 'error' | 'aborted'

export interface AiChatMessage {
  id: string
  /** 数据库中的消息 id，回写工具执行结果时使用 */
  dbId?: number
  role: 'user' | 'assistant'
  content: string
  reasoning: string
  createdAt: number
  status: AiMessageStatus
  error?: string
  context?: AiChatResult['context']
  elapsedMs?: number
  model?: string
  actions?: AiChatAction[]
  mcpCalls?: AiMcpCall[]
}

/* ---------------- 高驰 MCP ---------------- */

/** 一次后台同步的结果，status 与 dashboard 都会带回来 */
export interface CorosSyncReport {
  days: number
  from: string
  to: string
  activities: number
  details: number
  daily: number
  snapshots: string[]
  errors: { tool: string; message: string }[]
  startedAt: string
  finishedAt: string
  durationMs: number
}

export interface CorosSyncState {
  status: 'idle' | 'running' | 'done' | 'failed'
  startedAt: string | null
  syncedAt: string | null
  result: CorosSyncReport | null
}

export interface CorosStatus {
  connected: boolean
  endpoint: string
  account: string | null
  scope: string | null
  expiresAt: string | null
  toolsSyncedAt: string | null
  toolCount: number
  sync: CorosSyncState
}

export interface CorosConnectResult {
  authorizeUrl: string
  scope: string
  endpoint: string
  callbackUrl: string
  connected: boolean
}

export interface CorosSyncStartResult {
  started: boolean
  days: number
}

export type CorosSportCategory = 'running' | 'cycling' | 'swimming' | 'strength' | 'other'

/** coros_activities 的一行：一次运动，字段来自 MCP 文本报告 */
export interface CorosActivityRow {
  id: number
  labelId: string
  sportType: number | null
  sportName: string | null
  category: CorosSportCategory
  activityDate: string
  startTimestamp: number | null
  endTimestamp: number | null
  name: string | null
  durationSeconds: number
  distanceKm: number | null
  paceSeconds: number | null
  speedKmh: number | null
  avgHr: number | null
  calories: number | null
  sets: number | null
  trainingLoad: number | null
  avgCadence: number | null
  avgPower: number | null
  elevationGain: number | null
  bestKmSeconds: number | null
  trainingFocus: string | null
  performance: string | null
  detailSyncedAt: string | null
}

/** coros_daily_metrics 的一行：一天一行的健康与负荷，列都可空 */
export interface CorosDailyRow {
  id: number
  day: string
  steps: number | null
  calories: number | null
  exerciseMinutes: number | null
  stressAvg: number | null
  stressLevel: string | null
  sleepScore: number | null
  sleepMinutes: number | null
  mainSleepMinutes: number | null
  deepRatio: number | null
  lightRatio: number | null
  remRatio: number | null
  awakeMinutes: number | null
  sleepWindow: string | null
  napMinutes: number | null
  avgHr: number | null
  minHr: number | null
  maxHr: number | null
  restingHr: number | null
  hrvMs: number | null
  hrvStatus: string | null
  hrvBaseline: number | null
  hrvLow: number | null
  hrvHigh: number | null
  shortTermLoad: number | null
  longTermLoad: number | null
  loadRatio: number | null
  loadComment: string | null
}

export interface CorosFitnessSnapshot {
  vo2max: number | null
  runningLevel: number | null
  thresholdPaceSeconds: number | null
  predictions: { label: string; seconds: number | null }[]
}

export interface CorosRecoverySnapshot {
  recoveryPct: number | null
  level: string | null
  fullRecoveryHours: number | null
  raw: string
}

export interface CorosProfileSnapshot {
  heightCm: number | null
  weightKg: number | null
  birthday: string | null
  age: number | null
  gender: string | null
  nickname: string | null
}

export interface CorosScheduleItem {
  date: string
  name: string
  distanceKm: number | null
  estimatedSeconds: number | null
  loadTl: number | null
}

export interface CorosDashboard {
  connected: boolean
  account: string | null
  sync: CorosSyncState
  activities: CorosActivityRow[]
  daily: CorosDailyRow[]
  fitness: CorosFitnessSnapshot | null
  recovery: CorosRecoverySnapshot | null
  profile: CorosProfileSnapshot | null
  schedule: { items: CorosScheduleItem[] } | null
  devices: { text: string } | null
}

/* ---------------- 运维速查 ---------------- */

export interface OpsCommand {
  id: number
  title: string
  command: string
  description: string | null
  category: string
  createdAt: string
  updatedAt: string
}

export interface OpsCommandPayload {
  title: string
  command: string
  description?: string
  category?: string
}
import { Http, SseStream } from '../common/Http'
import {
  AiAction,
  AiChatResult,
  AiConversationDetail,
  AiConversationSummary,
  AiSettings,
  AiSettingsPayload,
  AiTestResult,
  CollectionItem,
  CollectionListResult,
  CollectionPayload,
  CollectionStats,
  DashboardSummary,
  Finance,
  FinanceListResult,
  FinancePayload,
  FinanceSummary,
  FillblankQuestion,
  FlashcardQuestion,
  Habit,
  HabitCheckInResult,
  HabitStats,
  HealthTrend,
  Interview,
  InterviewPayload,
  KnowledgeItem,
  KnowledgeListResult,
  KnowledgePayload,
  LearningTask,
  LoginResult,
  PracticeResultPayload,
  Schedule,
  SchedulePayload,
  ShoppingItem,
  User,
  WeightRecord,
  Workout,
  WorkoutListResult,
  WorkoutPayload,
  WorkoutStats
} from '../model/Models'

export interface LoginPayload {
  username: string
  password: string
}

export interface HabitPayload {
  name: string
  icon: string
}

export interface HealthPayload {
  weight: number
  recordDate: string
}

export interface LearningPayload {
  title: string
  duration: number
  status: string
}

export interface ScheduleUpdate {
  title?: string
  description?: string
  startTime?: string
  endTime?: string
  category?: string
  priority?: string
  isRemind?: boolean
  remindBefore?: number
  completed?: boolean
}

export interface ScheduleCompletedPayload {
  completed: boolean
}

export interface ShoppingPayload {
  name?: string
  price?: number
  status?: string
}

export interface CollectionUpdate {
  type?: string
  title?: string
  status?: string
  rating?: number | null
  year?: number | null
  coverUrl?: string | null
  comment?: string | null
}

export interface AiChatPayload {
  content: string
  conversationId?: number
  toolNames?: string[]
}

export interface AiActionReportPayload {
  index: number
  status: string
  error?: string
}

export interface RenamePayload {
  title: string
}

export interface RenameResult {
  id: number
  title: string
}

export interface UserPayload {
  username: string
  password: string
  role: string
}

export interface SuccessFlag {
  success: boolean
}

/** 流式对话回调，事件语义与后端 /ai/chat/stream 的 SSE 帧一一对应 */
export interface AiStreamHandlers {
  onMeta: (model: string, conversationId: number) => void
  onDelta: (text: string) => void
  onDone: (messageId: number, actions: AiAction[] | null) => void
  /** error 为空串表示正常结束，只会回调一次 */
  onEnd: (error: string) => void
}

function frameText(source: Record<string, Object>, key: string): string {
  const value = source[key]
  if (value === undefined || value === null) {
    return ''
  }
  return value.toString()
}

function frameNumber(source: Record<string, Object>, key: string): number {
  const parsed = parseFloat(frameText(source, key))
  return Number.isNaN(parsed) ? 0 : parsed
}

function frameActions(source: Record<string, Object>): AiAction[] | null {
  const value = source['actions']
  if (value === undefined || value === null) {
    return null
  }
  return value as AiAction[]
}

export class Api {
  /* ---------------- 认证 ---------------- */

  static login(username: string, password: string): Promise<LoginResult> {
    const payload: LoginPayload = { username: username, password: password }
    return Http.post<LoginResult>('/auth/login', payload)
  }

  static getProfile(): Promise<User> {
    return Http.get<User>('/auth/profile')
  }

  /* ---------------- 首页聚合 ---------------- */

  static getDashboard(): Promise<DashboardSummary> {
    return Http.get<DashboardSummary>('/dashboard/summary')
  }

  /* ---------------- 日程 ---------------- */

  static listSchedules(): Promise<Schedule[]> {
    return Http.get<Schedule[]>('/schedule')
  }

  static createSchedule(payload: SchedulePayload): Promise<Schedule> {
    return Http.post<Schedule>('/schedule', payload)
  }

  static updateSchedule(id: number, payload: SchedulePayload): Promise<Schedule> {
    return Http.patch<Schedule>('/schedule/' + id, payload)
  }

  static toggleScheduleCompleted(id: number, completed: boolean): Promise<Schedule> {
    const payload: ScheduleCompletedPayload = { completed: completed }
    return Http.patch<Schedule>('/schedule/' + id, payload)
  }

  static deleteSchedule(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/schedule/' + id)
  }

  /* ---------------- 习惯 ---------------- */

  static listHabits(): Promise<Habit[]> {
    return Http.get<Habit[]>('/habits')
  }

  static habitStats(days: number): Promise<HabitStats> {
    const query: Record<string, string> = { 'days': days.toString() }
    return Http.get<HabitStats>('/habits/stats', query)
  }

  static createHabit(payload: HabitPayload): Promise<Habit> {
    return Http.post<Habit>('/habits', payload)
  }

  static updateHabit(id: number, payload: HabitPayload): Promise<Habit> {
    return Http.patch<Habit>('/habits/' + id, payload)
  }

  static deleteHabit(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/habits/' + id)
  }

  static checkInHabit(id: number): Promise<HabitCheckInResult> {
    return Http.post<HabitCheckInResult>('/habits/' + id + '/check-in')
  }

  static cancelCheckIn(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/habits/' + id + '/check-in')
  }

  /* ---------------- 体重 / 健康 ---------------- */

  static listHealth(): Promise<WeightRecord[]> {
    return Http.get<WeightRecord[]>('/health/records')
  }

  static healthTrend(limit: number): Promise<HealthTrend> {
    const query: Record<string, string> = { 'limit': limit.toString() }
    return Http.get<HealthTrend>('/health/trend', query)
  }

  static createHealth(payload: HealthPayload): Promise<WeightRecord> {
    return Http.post<WeightRecord>('/health', payload)
  }

  static updateHealth(id: number, payload: HealthPayload): Promise<WeightRecord> {
    return Http.patch<WeightRecord>('/health/' + id, payload)
  }

  static deleteHealth(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/health/' + id)
  }

  /* ---------------- 学习 ---------------- */

  static listLearning(): Promise<LearningTask[]> {
    return Http.get<LearningTask[]>('/learning')
  }

  static createLearning(payload: LearningPayload): Promise<LearningTask> {
    return Http.post<LearningTask>('/learning', payload)
  }

  static updateLearning(id: number, payload: LearningPayload): Promise<LearningTask> {
    return Http.patch<LearningTask>('/learning/' + id, payload)
  }

  static deleteLearning(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/learning/' + id)
  }

  /* ---------------- 知识库（备忘） ---------------- */

  static listKnowledge(query: Record<string, string>): Promise<KnowledgeListResult> {
    return Http.get<KnowledgeListResult>('/knowledge', query)
  }

  static knowledgeDetail(id: number): Promise<KnowledgeItem> {
    return Http.get<KnowledgeItem>('/knowledge/' + id)
  }

  static knowledgeTags(): Promise<string[]> {
    return Http.get<string[]>('/knowledge/tags')
  }

  static createKnowledge(payload: KnowledgePayload): Promise<KnowledgeItem> {
    return Http.post<KnowledgeItem>('/knowledge', payload)
  }

  static updateKnowledge(id: number, payload: KnowledgePayload): Promise<KnowledgeItem> {
    return Http.patch<KnowledgeItem>('/knowledge/' + id, payload)
  }

  static deleteKnowledge(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/knowledge/' + id)
  }

  /* ---------------- 知识练习 ---------------- */

  static practiceCount(range: string): Promise<number> {
    const query: Record<string, string> = { 'range': range }
    return Http.get<number>('/practice/count', query)
  }

  static practiceTags(): Promise<string[]> {
    return Http.get<string[]>('/practice/tags')
  }

  static generatePractice(mode: string, range: string, count: number): Promise<Array<FlashcardQuestion | FillblankQuestion>> {
    const query: Record<string, string> = {
      'mode': mode,
      'range': range,
      'count': count.toString()
    }
    return Http.get<Array<FlashcardQuestion | FillblankQuestion>>('/practice/generate', query)
  }

  static submitPracticeResult(payload: PracticeResultPayload): Promise<SuccessFlag> {
    return Http.post<SuccessFlag>('/practice/result', payload)
  }

  /* ---------------- 书影音收藏 ---------------- */

  static listCollection(query: Record<string, string>): Promise<CollectionListResult> {
    return Http.get<CollectionListResult>('/collection', query)
  }

  static collectionStats(year: number): Promise<CollectionStats> {
    const query: Record<string, string> = { 'year': year.toString() }
    return Http.get<CollectionStats>('/collection/stats', query)
  }

  static createCollection(payload: CollectionPayload): Promise<CollectionItem> {
    return Http.post<CollectionItem>('/collection', payload)
  }

  static updateCollection(id: number, payload: CollectionPayload): Promise<CollectionItem> {
    return Http.patch<CollectionItem>('/collection/' + id, payload)
  }

  static updateCollectionStatus(id: number, status: string): Promise<CollectionItem> {
    const payload: CollectionUpdate = { status: status }
    return Http.patch<CollectionItem>('/collection/' + id, payload)
  }

  static deleteCollection(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/collection/' + id)
  }

  /* ---------------- 面试 ---------------- */

  static listInterviews(): Promise<Interview[]> {
    return Http.get<Interview[]>('/interviews')
  }

  static createInterview(payload: InterviewPayload): Promise<Interview> {
    return Http.post<Interview>('/interviews', payload)
  }

  static updateInterview(id: number, payload: InterviewPayload): Promise<Interview> {
    return Http.patch<Interview>('/interviews/' + id, payload)
  }

  static deleteInterview(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/interviews/' + id)
  }

  /* ---------------- 财务 ---------------- */

  static listFinance(query: Record<string, string>): Promise<FinanceListResult> {
    return Http.get<FinanceListResult>('/finance', query)
  }

  static financeSummary(month: string): Promise<FinanceSummary> {
    const query: Record<string, string> = { 'month': month }
    return Http.get<FinanceSummary>('/finance/summary', query)
  }

  static financeCategories(): Promise<string[]> {
    return Http.get<string[]>('/finance/categories')
  }

  static createFinance(payload: FinancePayload): Promise<Finance> {
    return Http.post<Finance>('/finance', payload)
  }

  static updateFinance(id: number, payload: FinancePayload): Promise<Finance> {
    return Http.patch<Finance>('/finance/' + id, payload)
  }

  static deleteFinance(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/finance/' + id)
  }

  /* ---------------- 健身 ---------------- */

  static listWorkouts(query: Record<string, string>): Promise<WorkoutListResult> {
    return Http.get<WorkoutListResult>('/workout', query)
  }

  static workoutStats(days: number): Promise<WorkoutStats> {
    const query: Record<string, string> = { 'days': days.toString() }
    return Http.get<WorkoutStats>('/workout/stats', query)
  }

  static createWorkout(payload: WorkoutPayload): Promise<Workout> {
    return Http.post<Workout>('/workout', payload)
  }

  static updateWorkout(id: number, payload: WorkoutPayload): Promise<Workout> {
    return Http.patch<Workout>('/workout/' + id, payload)
  }

  static deleteWorkout(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/workout/' + id)
  }

  /* ---------------- 待买清单 ---------------- */

  static listShopping(): Promise<ShoppingItem[]> {
    return Http.get<ShoppingItem[]>('/shopping')
  }

  static createShopping(name: string, price: number): Promise<ShoppingItem> {
    const payload: ShoppingPayload = { name: name, price: price }
    return Http.post<ShoppingItem>('/shopping', payload)
  }

  static updateShopping(id: number, status: string): Promise<ShoppingItem> {
    const payload: ShoppingPayload = { status: status }
    return Http.patch<ShoppingItem>('/shopping/' + id, payload)
  }

  static updateShoppingItem(id: number, name: string, price: number): Promise<ShoppingItem> {
    const payload: ShoppingPayload = { name: name, price: price }
    return Http.patch<ShoppingItem>('/shopping/' + id, payload)
  }

  static deleteShopping(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/shopping/' + id)
  }

  /* ---------------- AI ---------------- */

  static aiSettings(): Promise<AiSettings> {
    return Http.get<AiSettings>('/ai/settings')
  }

  static updateAiSettings(payload: AiSettingsPayload): Promise<AiSettings> {
    return Http.put<AiSettings>('/ai/settings', payload)
  }

  static clearAiKey(): Promise<AiSettings> {
    return Http.delete<AiSettings>('/ai/settings/key')
  }

  static testAi(payload: AiSettingsPayload): Promise<AiTestResult> {
    const body: Object = payload as Object
    return Http.post<AiTestResult>('/ai/settings/test', body, 60000)
  }

  static listAiConversations(): Promise<AiConversationSummary[]> {
    return Http.get<AiConversationSummary[]>('/ai/conversations')
  }

  static getAiConversation(id: number): Promise<AiConversationDetail> {
    return Http.get<AiConversationDetail>('/ai/conversations/' + id)
  }

  static renameAiConversation(id: number, title: string): Promise<RenameResult> {
    const payload: RenamePayload = { title: title }
    return Http.patch<RenameResult>('/ai/conversations/' + id, payload)
  }

  static deleteAiConversation(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/ai/conversations/' + id)
  }

  static aiChat(content: string, conversationId: number, toolNames: string[]): Promise<AiChatResult> {
    const payload: AiChatPayload = { content: content }
    if (conversationId > 0) {
      payload.conversationId = conversationId
    }
    if (toolNames.length > 0) {
      payload.toolNames = toolNames
    }
    const body: Object = payload as Object
    return Http.post<AiChatResult>('/ai/chat', body, 180000)
  }

  /** 流式对话：边生成边回显，返回的句柄可 cancel() 中断 */
  static aiChatStream(content: string, conversationId: number, toolNames: string[],
    handlers: AiStreamHandlers): SseStream {
    const payload: AiChatPayload = { content: content }
    if (conversationId > 0) {
      payload.conversationId = conversationId
    }
    if (toolNames.length > 0) {
      payload.toolNames = toolNames
    }
    let ended = false
    const finish = (message: string): void => {
      if (ended) {
        return
      }
      ended = true
      handlers.onEnd(message)
    }
    return new SseStream('/ai/chat/stream', payload as Object, {
      onEvent: (event: string, data: string): void => {
        let frame: Record<string, Object>
        try {
          frame = JSON.parse(data) as Record<string, Object>
        } catch (err) {
          return
        }
        if (event === 'meta') {
          handlers.onMeta(frameText(frame, 'model'), frameNumber(frame, 'conversationId'))
        } else if (event === 'delta') {
          handlers.onDelta(frameText(frame, 'content'))
        } else if (event === 'done') {
          handlers.onDone(frameNumber(frame, 'messageId'), frameActions(frame))
        } else if (event === 'error') {
          const message = frameText(frame, 'message')
          finish(message.length > 0 ? message : '生成失败')
        }
      },
      onFinish: (error: string): void => {
        finish(error)
      },
    })
  }

  /** 把操作卡片的执行结果回写给后端，历史里才不会重复提议同一件事 */
  static reportAiAction(messageId: number, index: number, status: string, error?: string): Promise<Object> {
    const payload: AiActionReportPayload = { index: index, status: status }
    if (error !== undefined && error.length > 0) {
      payload.error = error
    }
    return Http.patch<Object>('/ai/messages/' + messageId + '/actions', payload)
  }

  /* ---------------- 用户管理 ---------------- */

  static listUsers(): Promise<User[]> {
    return Http.get<User[]>('/users')
  }

  static createUser(payload: UserPayload): Promise<User> {
    return Http.post<User>('/users', payload)
  }

  static deleteUser(id: number): Promise<SuccessFlag> {
    return Http.delete<SuccessFlag>('/users/' + id)
  }
}

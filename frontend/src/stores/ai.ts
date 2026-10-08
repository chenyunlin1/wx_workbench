import { defineStore } from 'pinia'
import {
  chatWithAi,
  clearAiApiKey,
  createAiConversation,
  deleteAiConversation,
  getAiContext,
  getAiConversation,
  getAiSettings,
  listAiConversations,
  renameAiConversation,
  reportAiAction,
  streamAiChat,
  testAiConnection,
  updateAiSettings,
} from '@/api/ai'
import { AI_TOOL_NAMES, runAiAction } from '@/utils/ai-actions'
import type {
  AiChatMessage,
  AiChatPayload,
  AiContextScope,
  AiContextSnapshot,
  AiConversationDetail,
  AiConversationSummary,
  AiSettings,
  AiSettingsPayload,
  AiTestResult,
} from '@/types'

let activeController: AbortController | null = null

const createId = () => `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`

/** 数据库消息 → 界面消息 */
const toViewMessage = (message: AiConversationDetail['messages'][number]): AiChatMessage => ({
  id: `db-${message.id}`,
  dbId: message.id,
  role: message.role,
  content: message.content,
  reasoning: message.reasoning ?? '',
  createdAt: message.createdAt ? Date.parse(message.createdAt) : Date.now(),
  status: message.error ? 'error' : 'done',
  error: message.error ?? undefined,
  context: message.contextMeta ?? undefined,
  elapsedMs: message.elapsedMs ?? undefined,
  model: message.model ?? undefined,
  actions: message.actions ?? undefined,
})

export const useAiStore = defineStore('ai', {
  state: () => ({
    conversations: [] as AiConversationSummary[],
    activeConversationId: null as number | null,
    /** 已点「新建对话」但还没发出第一条消息的草稿态 */
    isDraft: false,
    messages: [] as AiChatMessage[],
    settings: null as AiSettings | null,
    contextPreview: null as AiContextSnapshot | null,
    loadingConversations: false,
    loadingMessages: false,
    loadingSettings: false,
    loadingContext: false,
    sending: false,
    saving: false,
    testing: false,
    error: '',
  }),
  getters: {
    hasApiKey: (state) => Boolean(state.settings?.hasApiKey),
    contextScope: (state): AiContextScope[] => state.settings?.contextScope ?? [],
    model: (state) => state.settings?.model ?? 'deepseek-chat',
    activeConversation: (state) =>
      state.conversations.find((item) => item.id === state.activeConversationId) ?? null,
    activeTitle: (state) =>
      state.isDraft
        ? '新对话'
        : (state.conversations.find((item) => item.id === state.activeConversationId)?.title ??
          '新对话'),
  },
  actions: {
    async loadSettings() {
      this.loadingSettings = true
      try {
        this.settings = await getAiSettings()
        return this.settings
      } finally {
        this.loadingSettings = false
      }
    },

    async saveSettings(payload: AiSettingsPayload) {
      this.saving = true
      try {
        this.settings = await updateAiSettings(payload)
        return this.settings
      } finally {
        this.saving = false
      }
    },

    async removeApiKey() {
      this.saving = true
      try {
        this.settings = await clearAiApiKey()
        return this.settings
      } finally {
        this.saving = false
      }
    },

    async testConnection(payload: { apiKey?: string; baseUrl?: string; model?: string }) {
      this.testing = true
      try {
        return (await testAiConnection(payload)) as AiTestResult
      } finally {
        this.testing = false
      }
    },

    async loadContext(scope?: AiContextScope[], force = false) {
      if (this.contextPreview && !force && !scope) return this.contextPreview
      this.loadingContext = true
      try {
        this.contextPreview = await getAiContext(scope ?? this.contextScope)
        return this.contextPreview
      } finally {
        this.loadingContext = false
      }
    },

    /** 拉取会话列表；autoSelect 为真时默认打开最近一条 */
    async loadConversations(autoSelect = false) {
      this.loadingConversations = true
      try {
        const list = await listAiConversations()
        this.conversations = list

        if (
          this.activeConversationId &&
          !list.some((item) => item.id === this.activeConversationId)
        ) {
          this.activeConversationId = null
          this.messages = []
        }

        if (autoSelect && !this.activeConversationId && !this.isDraft && list.length) {
          await this.selectConversation(list[0].id)
        }
      } finally {
        this.loadingConversations = false
      }
    },

    async selectConversation(id: number) {
      if (!id) return
      this.loadingMessages = true
      this.error = ''
      try {
        const detail = await getAiConversation(id)
        this.activeConversationId = id
        this.isDraft = false
        this.messages = detail.messages.map(toViewMessage)
      } finally {
        this.loadingMessages = false
      }
    },

    /** 新建会话：进入草稿态，发出第一条消息时由后端落库 */
    newConversation() {
      activeController?.abort()
      activeController = null
      this.sending = false
      this.activeConversationId = null
      this.isDraft = true
      this.messages = []
      this.error = ''
    },

    /** 立即在数据库里建一条空会话（用于「新建对话」按钮落到列表） */
    async createConversation(title?: string) {
      const conversation = await createAiConversation(title)
      await this.loadConversations()
      this.activeConversationId = conversation.id
      this.isDraft = false
      this.messages = []
      return conversation
    },

    async renameConversation(id: number, title: string) {
      const trimmed = title.trim()
      if (!trimmed) return
      const updated = await renameAiConversation(id, trimmed)
      const target = this.conversations.find((item) => item.id === id)
      if (target) target.title = updated.title
    },

    async removeConversation(id: number) {
      await deleteAiConversation(id)
      this.conversations = this.conversations.filter((item) => item.id !== id)
      if (this.activeConversationId === id) {
        this.activeConversationId = null
        this.messages = []
        const next = this.conversations[0]
        if (next) await this.selectConversation(next.id)
        else this.isDraft = true
      }
    },

    stop() {
      activeController?.abort()
      activeController = null
      this.sending = false
    },

    async send(raw: string) {
      const content = raw.trim()
      if (!content || this.sending) return

      this.error = ''

      this.messages.push(
        {
          id: createId(),
          role: 'user',
          content,
          reasoning: '',
          createdAt: Date.now(),
          status: 'done',
        } as AiChatMessage,
        {
          id: createId(),
          role: 'assistant',
          content: '',
          reasoning: '',
          createdAt: Date.now(),
          status: 'streaming',
          model: this.model,
          actions: [],
        } as AiChatMessage,
      )

      // Pinia 的 state 是 reactive 的，push 进去的是原始对象，
      // 必须拿数组返回的代理来写，否则不会触发流式回显。
      const assistant = this.messages[this.messages.length - 1]

      const payload: AiChatPayload = {
        conversationId: this.activeConversationId ?? undefined,
        content,
        contextScope: this.contextScope,
        useContext: true,
        toolNames: AI_TOOL_NAMES,
      }

      const controller = new AbortController()
      activeController = controller
      this.sending = true

      let streamError = ''
      let aborted = false

      try {
        await streamAiChat(
          payload,
          {
            onMeta: (meta) => {
              assistant.context = meta.context
              if (meta.model) assistant.model = meta.model

              if (meta.conversationId && meta.conversationId !== this.activeConversationId) {
                this.activeConversationId = meta.conversationId
                this.isDraft = false
                // 新会话立刻出现在列表里（标题由后端用首条消息生成）
                void this.loadConversations()
              }
            },
            onDelta: (chunk) => {
              assistant.content += chunk
            },
            onReasoning: (chunk) => {
              assistant.reasoning += chunk
            },
            onAction: (action, index) => {
              if (!assistant.actions) assistant.actions = []
              // 后端已按顺序下发，占位写入保证 index 与落库的 actions 对齐
              assistant.actions[index] = action
            },
            onMcp: (call) => {
              // 高驰工具由服务端执行，结果已经在正文里，这里只是标一下数据来源
              assistant.mcpCalls = (assistant.mcpCalls ?? []).concat([call])
            },
            onDone: (done) => {
              assistant.status = 'done'
              assistant.elapsedMs = done.elapsedMs
              if (done.model) assistant.model = done.model
              if (done.messageId) assistant.dbId = done.messageId
              if (done.actions?.length) assistant.actions = done.actions
              if (done.mcpCalls?.length) assistant.mcpCalls = done.mcpCalls
            },
            onError: (message) => {
              streamError = message
            },
          },
          controller.signal,
        )

        if (streamError) {
          if (assistant.content.trim()) {
            assistant.status = 'done'
            assistant.error = streamError
          } else {
            assistant.status = 'error'
            assistant.error = streamError
          }
        } else if (assistant.status === 'streaming') {
          // 只调用工具、正文为空的回复是正常结果，卡片本身就是答案
          if (assistant.content.trim() || assistant.actions?.length) {
            assistant.status = 'done'
          } else {
            assistant.status = 'error'
            assistant.error = '模型没有返回内容'
          }
        }
      } catch (error) {
        const isAbort =
          (error instanceof DOMException && error.name === 'AbortError') ||
          (typeof error === 'object' &&
            error !== null &&
            (error as { name?: string }).name === 'AbortError')

        if (isAbort) {
          aborted = true
          if (assistant.content.trim() || assistant.actions?.length) {
            assistant.status = 'done'
          } else {
            assistant.status = 'aborted'
            assistant.error = '已停止生成'
          }
        } else {
          const message = error instanceof Error ? error.message : '对话失败'

          // 流式不可用时退回一次性接口
          if (!assistant.content.trim()) {
            try {
              const result = await chatWithAi(payload)
              assistant.content = result.content
              assistant.context = result.context
              assistant.model = result.model
              assistant.status = 'done'
              assistant.actions = result.actions ?? []
              assistant.mcpCalls = result.mcpCalls ?? []
              if (result.messageId) assistant.dbId = result.messageId
              if (result.conversationId && !this.activeConversationId) {
                this.activeConversationId = result.conversationId
                this.isDraft = false
              }
            } catch (fallbackError) {
              assistant.status = 'error'
              assistant.error =
                fallbackError instanceof Error ? fallbackError.message : message
            }
          } else {
            assistant.status = 'done'
            assistant.error = message
          }
        }
      } finally {
        if (activeController === controller) activeController = null
        this.sending = false
        if (assistant.status === 'error') {
          this.error = assistant.error ?? '对话失败'
        }
        if (aborted && !assistant.content.trim() && !assistant.actions?.length) {
          this.messages = this.messages.filter((message) => message.id !== assistant.id)
        }
        // 刷新列表以更新摘要、时间与消息数
        void this.loadConversations()
      }
    },

    /**
     * 执行或取消 AI 提出的写入操作。真正调用业务接口的是这里，
     * 后端只负责整理参数，所以创建结果必须回写给后端，避免重开会话时重复确认。
     */
    async applyAction(
      message: AiChatMessage,
      index: number,
      approve: boolean,
    ): Promise<{ ok: boolean; tip: string }> {
      const action = message.actions?.[index]
      if (!action || action.status !== 'pending') return { ok: false, tip: '该操作已处理' }

      if (!approve) {
        action.status = 'cancelled'
        void this.syncActionStatus(message, index, 'cancelled')
        return { ok: true, tip: '已取消' }
      }

      try {
        const tip = await runAiAction(action.tool, action.args)
        action.status = 'done'
        action.error = null
        void this.syncActionStatus(message, index, 'done')
        return { ok: true, tip }
      } catch (error) {
        const detail = error instanceof Error ? error.message : '创建失败'
        action.status = 'failed'
        action.error = detail
        void this.syncActionStatus(message, index, 'failed', detail)
        return { ok: false, tip: detail }
      }
    },

    async syncActionStatus(
      message: AiChatMessage,
      index: number,
      status: 'done' | 'failed' | 'cancelled',
      error?: string,
    ) {
      if (!message.dbId) return
      try {
        await reportAiAction(message.dbId, index, status, error)
      } catch {
        // 业务接口已成功，回写状态失败只影响下次打开时的显示，不打扰用户
      }
    },
  },
})

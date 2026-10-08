import { API_BASE_URL, getToken, removeToken, request } from './index'
import { parseSseChunk, parseSseFrame, type SseFrame } from '@/utils/sse'
import type {
  AiChatAction,
  AiChatPayload,
  AiChatResult,
  AiContextScope,
  AiContextSnapshot,
  AiMcpCall,
  AiConversationDetail,
  AiConversationSummary,
  AiSettings,
  AiSettingsPayload,
  AiStreamDone,
  AiStreamMeta,
  AiTestResult,
} from '@/types'

export const getAiSettings = () =>
  request<AiSettings>({
    url: '/ai/settings',
    method: 'GET',
  })

export const updateAiSettings = (data: AiSettingsPayload) =>
  request<AiSettings>({
    url: '/ai/settings',
    method: 'PUT',
    data,
  })

export const clearAiApiKey = () =>
  request<AiSettings>({
    url: '/ai/settings/key',
    method: 'DELETE',
  })

export const testAiConnection = (data: { apiKey?: string; baseUrl?: string; model?: string }) =>
  request<AiTestResult>({
    url: '/ai/settings/test',
    method: 'POST',
    data,
  })

export const getAiContext = (scope?: AiContextScope[]) =>
  request<AiContextSnapshot>({
    url: '/ai/context',
    method: 'GET',
    params: scope && scope.length ? { scope: scope.join(',') } : undefined,
  })

export const listAiConversations = () =>
  request<AiConversationSummary[]>({
    url: '/ai/conversations',
    method: 'GET',
  })

export const createAiConversation = (title?: string) =>
  request<AiConversationSummary>({
    url: '/ai/conversations',
    method: 'POST',
    data: title ? { title } : {},
  })

export const getAiConversation = (id: number) =>
  request<AiConversationDetail>({
    url: `/ai/conversations/${id}`,
    method: 'GET',
  })

export const renameAiConversation = (id: number, title: string) =>
  request<{ id: number; title: string }>({
    url: `/ai/conversations/${id}`,
    method: 'PATCH',
    data: { title },
  })

export const deleteAiConversation = (id: number) =>
  request<{ success: boolean }>({
    url: `/ai/conversations/${id}`,
    method: 'DELETE',
  })

export const chatWithAi = (data: AiChatPayload) =>
  request<AiChatResult>({
    url: '/ai/chat',
    method: 'POST',
    data,
  })

/** 回写工具执行的真实结果，重开会话时才不会重复确认 */
export const reportAiAction = (messageId: number, index: number, status: 'done' | 'failed' | 'cancelled', error?: string) =>
  request<{ messageId: number; actions: AiChatAction[] }>({
    url: `/ai/messages/${messageId}/actions`,
    method: 'PATCH',
    data: { index, status, error },
  })

export interface AiStreamHandlers {
  onMeta?: (meta: AiStreamMeta) => void
  onDelta?: (content: string) => void
  onReasoning?: (content: string) => void
  onAction?: (action: AiChatAction, index: number) => void
  onMcp?: (call: AiMcpCall) => void
  onDone?: (payload: AiStreamDone) => void
  onError?: (message: string) => void
}

const dispatchFrame = (frame: SseFrame, handlers: AiStreamHandlers) => {
  let payload: Record<string, unknown>
  try {
    payload = JSON.parse(frame.data) as Record<string, unknown>
  } catch {
    return
  }

  switch (frame.event) {
    case 'meta':
      handlers.onMeta?.(payload as unknown as AiStreamMeta)
      break
    case 'delta':
      handlers.onDelta?.(String(payload.content ?? ''))
      break
    case 'reasoning':
      handlers.onReasoning?.(String(payload.content ?? ''))
      break
    case 'action':
      handlers.onAction?.(payload.action as AiChatAction, Number(payload.index ?? 0))
      break
    case 'mcp':
      handlers.onMcp?.({
        name: String(payload.name ?? ''),
        label: String(payload.label ?? ''),
        ok: Boolean(payload.ok),
      })
      break
    case 'done':
      handlers.onDone?.(payload as unknown as AiStreamDone)
      break
    case 'error':
      handlers.onError?.(String(payload.message ?? '生成失败'))
      break
    default:
      break
  }
}

/**
 * 通过 SSE 流式对话。使用原生 fetch，因为 axios 在浏览器端拿不到流式响应体。
 */
export const streamAiChat = async (
  data: AiChatPayload,
  handlers: AiStreamHandlers,
  signal?: AbortSignal,
) => {
  const token = getToken()
  let response: Response

  try {
    response = await fetch(`${API_BASE_URL}/ai/chat/stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(data),
      signal,
    })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw error
    throw new Error('无法连接到 AI 服务，请检查后端是否已启动')
  }

  if (!response.ok) {
    let message = `请求失败（${response.status}）`
    try {
      const body = (await response.json()) as { message?: string }
      if (body?.message) message = body.message
    } catch {
      // 保留默认提示
    }

    if (response.status === 401) {
      removeToken()
      localStorage.removeItem('life-workbench-user')
      if (location.pathname !== '/login') location.href = '/login'
    }

    throw new Error(message)
  }

  if (!response.body) throw new Error('当前浏览器不支持流式响应，请更换浏览器后重试')

  const reader = response.body.getReader()
  const decoder = new TextDecoder('utf-8')
  let buffer = ''

  for (;;) {
    const { value, done } = await reader.read()
    if (done) break

    buffer += decoder.decode(value, { stream: true })
    const { frames, rest } = parseSseChunk(buffer)
    buffer = rest
    for (const frame of frames) dispatchFrame(frame, handlers)
  }

  const tail = parseSseFrame(buffer)
  if (tail) dispatchFrame(tail, handlers)
}

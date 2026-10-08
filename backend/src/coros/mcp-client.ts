import { COROS_PROTOCOL_VERSION, COROS_REQUEST_TIMEOUT_MS, COROS_TOOL_TIMEOUT_MS } from './coros.constants'

/** MCP 工具清单里的一项；inputSchema 本身就是标准 JSON Schema */
export interface McpTool {
  name: string
  title?: string
  description?: string
  inputSchema?: Record<string, unknown>
}

export interface McpToolResult {
  text: string
  isError: boolean
}

interface JsonRpcFrame {
  jsonrpc?: string
  id?: number | string
  result?: unknown
  error?: { code?: number; message?: string; data?: unknown }
}

/** 401/403：access_token 不被接受，上层刷新令牌后重试一次 */
export class McpUnauthorizedError extends Error {
  constructor(message = '高驰拒绝了当前授权') {
    super(message)
    this.name = 'McpUnauthorizedError'
  }
}

/**
 * streamable HTTP 允许服务端用普通 JSON 或用 SSE 帧回同一条响应，
 * 两种写法在这里收敛成一个 JSON-RPC 响应。
 */
const readFrame = async (response: Response, id?: number): Promise<JsonRpcFrame | null> => {
  const contentType = response.headers.get('content-type') ?? ''
  const text = await response.text().catch(() => '')
  if (!text.trim()) return null

  const frames: JsonRpcFrame[] = []
  const push = (payload: string) => {
    try {
      frames.push(JSON.parse(payload) as JsonRpcFrame)
    } catch {
      // SSE 里混着心跳和其他非 JSON 帧，跳过即可
    }
  }

  if (contentType.includes('text/event-stream')) {
    for (const line of text.split(/\r?\n/)) {
      const trimmed = line.trim()
      if (!trimmed.startsWith('data:')) continue
      const payload = trimmed.slice(5).trim()
      if (payload && payload !== '[DONE]') push(payload)
    }
  } else {
    push(text)
  }

  if (!frames.length) return null
  if (id !== undefined) {
    const matched = frames.find((frame) => String(frame.id) === String(id))
    if (matched) return matched
  }
  return frames.find((frame) => frame.result !== undefined || frame.error !== undefined) ?? null
}

const flattenContent = (result: unknown): McpToolResult => {
  if (!result || typeof result !== 'object') return { text: String(result ?? ''), isError: false }

  const body = result as { content?: unknown; structuredContent?: unknown; isError?: boolean }
  const parts: string[] = []

  if (Array.isArray(body.content)) {
    for (const item of body.content) {
      if (!item || typeof item !== 'object') continue
      const text = (item as { text?: string }).text
      if (text) parts.push(text)
    }
  }
  if (body.structuredContent !== undefined) parts.push(JSON.stringify(body.structuredContent))
  if (!parts.length) parts.push(JSON.stringify(result))

  return { text: parts.join('\n'), isError: Boolean(body.isError) }
}

/**
 * 极简 MCP 客户端：只做 streamable HTTP 上的 JSON-RPC。
 * 顺序固定为 initialize → notifications/initialized → 业务方法，
 * 会话 ID 由服务端在 initialize 响应头里给出，后续请求必须带上。
 */
export class McpClient {
  private sessionId: string | null = null
  private requestId = 0
  private initialized = false

  constructor(
    private readonly endpoint: string,
    private readonly accessToken: string,
  ) {}

  private async send(body: Record<string, unknown>, timeoutMs: number) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)

    try {
      const response = await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          // 服务端可能用 SSE 回单条响应，两种都得声明能收
          Accept: 'application/json, text/event-stream',
          Authorization: `Bearer ${this.accessToken}`,
          ...(this.sessionId ? { 'mcp-session-id': this.sessionId } : {}),
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      })

      if (response.status === 401 || response.status === 403) {
        throw new McpUnauthorizedError(`高驰 MCP 拒绝了授权（${response.status}）`)
      }

      if (response.status === 404 && this.sessionId) {
        // 会话被服务端回收：丢掉 ID，让下一次调用重新握手
        this.sessionId = null
        this.initialized = false
        throw new Error('高驰 MCP 会话已过期，请重试')
      }

      if (!response.ok) {
        const detail = (await response.text().catch(() => '')).slice(0, 200)
        throw new Error(`高驰 MCP 返回 ${response.status}${detail ? `：${detail}` : ''}`)
      }

      return response
    } catch (error) {
      if (error instanceof McpUnauthorizedError) throw error
      if (error instanceof Error && error.name === 'AbortError') {
        throw new Error('高驰 MCP 响应超时，请稍后重试')
      }
      if (error instanceof Error && error.message.startsWith('高驰 MCP')) throw error
      throw new Error(
        `无法连接高驰 MCP 服务（${error instanceof Error ? error.message : String(error)}）`,
      )
    } finally {
      clearTimeout(timer)
    }
  }

  /** 带 id 的请求读响应；通知只看状态码 */
  private async rpc<T>(method: string, params?: Record<string, unknown>, timeoutMs = COROS_REQUEST_TIMEOUT_MS) {
    const id = ++this.requestId
    const response = await this.send(
      { jsonrpc: '2.0', id, method, ...(params ? { params } : {}) },
      timeoutMs,
    )

    const frame = await readFrame(response, id)
    if (frame?.error?.message) throw new Error(`高驰 MCP ${method} 失败：${frame.error.message}`)
    return (frame?.result ?? null) as T
  }

  private async notify(method: string) {
    const response = await this.send({ jsonrpc: '2.0', method }, COROS_REQUEST_TIMEOUT_MS)
    // 通知没有响应体，读完丢掉以免连接挂着
    await response.text().catch(() => '')
  }

  private async ensureReady() {
    if (this.initialized) return

    const id = ++this.requestId
    const response = await this.send(
      {
        jsonrpc: '2.0',
        id,
        method: 'initialize',
        params: {
          protocolVersion: COROS_PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: { name: 'LifeOS', version: '1.0.0' },
        },
      },
      COROS_REQUEST_TIMEOUT_MS,
    )

    this.sessionId = response.headers.get('mcp-session-id')
    const frame = await readFrame(response, id)
    if (frame?.error?.message) throw new Error(`高驰 MCP 握手失败：${frame.error.message}`)
    this.initialized = true

    if (this.sessionId) {
      await this.notify('notifications/initialized').catch(() => {
        // 个别实现不认这条通知，不影响后续调用
      })
    }
  }

  async listTools(): Promise<McpTool[]> {
    await this.ensureReady()

    const tools: McpTool[] = []
    let cursor: string | undefined

    for (let page = 0; page < 5; page += 1) {
      const result = await this.rpc<{ tools?: McpTool[]; nextCursor?: string }>(
        'tools/list',
        cursor ? { cursor } : undefined,
      )
      tools.push(...(result?.tools ?? []))
      cursor = result?.nextCursor
      if (!cursor) break
    }

    return tools
  }

  async callTool(name: string, args: Record<string, unknown>): Promise<McpToolResult> {
    await this.ensureReady()
    const result = await this.rpc<unknown>(
      'tools/call',
      { name, arguments: args },
      COROS_TOOL_TIMEOUT_MS,
    )
    return flattenContent(result)
  }
}

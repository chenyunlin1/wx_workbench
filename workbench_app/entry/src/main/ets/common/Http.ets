import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { Session } from '../store/Session'

export interface ApiEnvelope<T> {
  code: number
  message: string
  data: T
}

export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

function toHttpMethod(method: string): http.RequestMethod {
  switch (method) {
    case 'POST':
      return http.RequestMethod.POST
    case 'PUT':
      return http.RequestMethod.PUT
    case 'PATCH':
      return http.RequestMethod.PATCH
    case 'DELETE':
      return http.RequestMethod.DELETE
    case 'HEAD':
      return http.RequestMethod.HEAD
    default:
      return http.RequestMethod.GET
  }
}

function buildQuery(query?: Record<string, string>): string {
  if (query === undefined) {
    return ''
  }
  const keys = Object.keys(query)
  const parts: string[] = []
  for (const key of keys) {
    const value = query[key]
    if (value.length === 0) {
      continue
    }
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value))
  }
  if (parts.length === 0) {
    return ''
  }
  return '?' + parts.join('&')
}

interface ErrorBody {
  message?: string
}

/**
 * 统一 HTTP 客户端：
 * - 自动拼接 baseUrl 与 /api 前缀
 * - 自动携带 Bearer Token，401 时清除会话回登录页
 * - 统一解包 { code, message, data } 响应
 * 说明：鸿蒙 HttpMethod 枚举不含 PATCH，后端已为所有 PATCH 路由补充了 PUT 别名。
 */
export class Http {
  static async request<T>(method: string, path: string, query?: Record<string, string>,
    body?: Object | null, timeoutMs?: number): Promise<T> {
    const url = Session.serverUrl.replace(/\/+$/, '') + '/api' + path + buildQuery(query)
    const timeout = timeoutMs === undefined ? 15000 : timeoutMs

    const client = http.createHttp()
    try {
      const options: http.HttpRequestOptions = {
        method: toHttpMethod(method),
        header: Http.buildHeaders(),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout
      }
      if (body !== undefined && body !== null) {
        options.extraData = JSON.stringify(body)
      }
      const response = await client.request(url, options)
      return Http.handleResponse<T>(response)
    } catch (err) {
      if (err instanceof ApiError) {
        throw err
      }
      throw new ApiError('网络连接异常，请检查服务器地址与网络', -1)
    } finally {
      client.destroy()
    }
  }

  static buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    }
    if (Session.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + Session.token
    }
    return headers
  }

  private static handleResponse<T>(response: http.HttpResponse): T {
    const status = response.responseCode
    const raw = (response.result ?? '') as string

    if (status === 200 || status === 201) {
      let envelope: ApiEnvelope<T>
      try {
        envelope = JSON.parse(raw) as ApiEnvelope<T>
      } catch (err) {
        throw new ApiError('响应解析失败', status)
      }
      if (envelope.code === 0) {
        return envelope.data
      }
      throw new ApiError(envelope.message.length > 0 ? envelope.message : '请求失败', status)
    }

    if (status === 401) {
      Session.logout(true)
      throw new ApiError('登录已过期，请重新登录', 401)
    }

    let message = '请求失败（' + status + '）'
    try {
      const errBody = JSON.parse(raw) as ErrorBody
      if (errBody.message !== undefined && errBody.message.length > 0) {
        message = errBody.message
      }
    } catch (err) {
      // 保留默认提示
    }
    throw new ApiError(message, status)
  }

  static get<T>(path: string, query?: Record<string, string>): Promise<T> {
    return Http.request<T>('GET', path, query)
  }

  static post<T>(path: string, body?: Object | null, timeoutMs?: number): Promise<T> {
    return Http.request<T>('POST', path, undefined, body, timeoutMs)
  }

  static put<T>(path: string, body?: Object | null): Promise<T> {
    return Http.request<T>('PUT', path, undefined, body)
  }

  static patch<T>(path: string, body?: Object | null): Promise<T> {
    return Http.request<T>('PATCH', path, undefined, body)
  }

  static delete<T>(path: string): Promise<T> {
    return Http.request<T>('DELETE', path)
  }
}

export interface StreamHandlers {
  onEvent: (event: string, data: string) => void
  /** error 为空串表示服务端正常结束 */
  onFinish: (error: string) => void
}

/**
 * SSE 客户端。Http.request 要等整个响应结束才拿到 body，流式回复必须用
 * requestInStream 逐块取字节，再按空行切帧（event: xxx / data: {...}）。
 */
export class SseStream {
  private client: http.HttpRequest = http.createHttp()
  private decoder: util.TextDecoder = new util.TextDecoder('utf-8')
  private handlers: StreamHandlers
  private buffer: string = ''
  private framed: boolean = false
  private closed: boolean = false

  constructor(path: string, body: Object, handlers: StreamHandlers) {
    this.handlers = handlers
    const url = Session.serverUrl.replace(/\/+$/, '') + '/api' + path
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: Http.buildHeaders(),
      connectTimeout: 15000,
      readTimeout: 180000,
      usingCache: false
    }
    options.extraData = JSON.stringify(body)
    this.client.on('dataReceive', (chunk: ArrayBuffer) => {
      this.receive(chunk)
    })
    this.client.on('dataEnd', () => {
      this.complete('')
    })
    this.client.requestInStream(url, options).catch((err: Object) => {
      this.complete(err instanceof Error ? err.message : '流式请求失败')
    })
  }

  /** 主动断开：离开页面或用户停止生成时调用，不会再触发 onFinish */
  cancel(): void {
    if (this.closed) {
      return
    }
    this.closed = true
    this.release()
  }

  private receive(chunk: ArrayBuffer): void {
    if (this.closed) {
      return
    }
    // stream: true 让跨块被截断的中文字节留到下一次解码，避免出现乱码
    this.buffer += this.decoder.decodeWithStream(new Uint8Array(chunk), { stream: true })
    let cut = this.buffer.indexOf('\n\n')
    while (cut >= 0) {
      const frame = this.buffer.substring(0, cut)
      this.buffer = this.buffer.substring(cut + 2)
      this.dispatch(frame)
      cut = this.buffer.indexOf('\n\n')
    }
  }

  private dispatch(frame: string): void {
    let event = 'message'
    let data = ''
    for (const line of frame.split('\n')) {
      const text = line.trim()
      if (text.startsWith('event:')) {
        event = text.substring(6).trim()
      } else if (text.startsWith('data:')) {
        data += text.substring(5).trim()
      }
    }
    if (data.length === 0) {
      return
    }
    this.framed = true
    this.handlers.onEvent(event, data)
  }

  private complete(error: string): void {
    if (this.closed) {
      return
    }
    this.closed = true
    let message = error
    if (message.length === 0 && !this.framed) {
      message = this.plainError()
    }
    this.release()
    this.handlers.onFinish(message)
  }

  /** 一帧 SSE 都没收到，说明后端直接回了 JSON 错误 */
  private plainError(): string {
    const tail = this.buffer.trim()
    if (tail.length === 0) {
      return '没有收到回复'
    }
    try {
      const body = JSON.parse(tail) as ErrorBody
      if (body.message !== undefined && body.message.length > 0) {
        return body.message
      }
    } catch (err) {
      // 不是 JSON，按网络问题提示
    }
    return '生成中断，请重试'
  }

  private release(): void {
    this.client.off('dataReceive')
    this.client.off('dataEnd')
    this.client.destroy()
  }
}

import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { InjectRepository } from '@nestjs/typeorm'
import type { Request as ExpressRequest, Response as ExpressResponse } from 'express'
import { Repository } from 'typeorm'
import type { User } from '../entities'
import { COROS_MAX_TOOL_ROUNDS, COROS_TOOL_PREFIX } from '../coros/coros.constants'
import { CorosService } from '../coros/coros.service'
import { AiContextService, type AiContextSnapshot } from './ai-context.service'
import { AiConversationService } from './ai-conversation.service'
import { AiMessageRole } from './ai-message.entity'
import {
  aiToolInstruction,
  buildAiToolPayload,
  normalizeToolCalls,
  type AiAction,
  type RawToolCall,
} from './ai-tools'
import {
  AI_HISTORY_LIMIT,
  AI_MESSAGE_MAX_LENGTH,
  AI_REQUEST_TIMEOUT_MS,
  AI_STREAM_IDLE_TIMEOUT_MS,
  AI_STREAM_MAX_TOKENS,
  DEFAULT_AI_BASE_URL,
  DEFAULT_AI_MODEL,
  DEFAULT_AI_PROVIDER,
  DEFAULT_AI_SYSTEM_PROMPT,
  DEFAULT_AI_TEMPERATURE,
} from './ai.constants'
import { AiSetting } from './ai-setting.entity'
import type { ChatDto } from './dto/chat.dto'
import type { TestConnectionDto } from './dto/test-connection.dto'
import type { UpdateAiSettingsDto } from './dto/update-ai-settings.dto'

interface RuntimeConfig {
  apiKey: string
  baseUrl: string
  model: string
  temperature: number
  systemPrompt: string
  contextScope: string[]
}

/**
 * 发给上游的对话消息。
 * tool_calls / role:'tool' 只在服务端执行 MCP 工具的那几轮里出现，落库和返回前端都用不到。
 */
interface CompletionToolCall {
  id: string
  type: 'function'
  function: { name: string; arguments: string }
}

interface CompletionMessage {
  role: 'system' | 'user' | 'assistant' | 'tool'
  content: string
  tool_calls?: CompletionToolCall[]
  tool_call_id?: string
}

interface CompletionUsage {
  prompt_tokens?: number
  completion_tokens?: number
  total_tokens?: number
}

export type { CompletionUsage }

/** 流式返回时 tool_calls 按 index 分片到达，arguments 是一段一段拼起来的 */
interface ToolCallFragment {
  index?: number
  id?: string
  function?: { name?: string; arguments?: string }
}

interface CompletionChunk {
  model?: string
  usage?: CompletionUsage | null
  choices?: Array<{
    delta?: {
      content?: string | null
      reasoning_content?: string | null
      tool_calls?: ToolCallFragment[]
    }
    message?: {
      content?: string | null
      reasoning_content?: string | null
      tool_calls?: RawToolCall[]
    }
    finish_reason?: string | null
  }>
  error?: { message?: string; type?: string; code?: string }
}

const maskApiKey = (apiKey: string) => {
  if (apiKey.length <= 8) return `${apiKey.slice(0, 2)}****`
  return `${apiKey.slice(0, 5)}****${apiKey.slice(-4)}`
}

/** 接口返回的脱敏预览值会被当成“未修改”，不应写回数据库。 */
const isMaskedApiKey = (value: string) => value.includes('****') || value.includes('••')

const normalizeBaseUrl = (raw: string) => {
  const trimmed = raw.trim().replace(/\/+$/, '')
  if (!trimmed) throw new BadRequestException('接口地址不能为空')
  let parsed: URL
  try {
    parsed = new URL(trimmed)
  } catch {
    throw new BadRequestException('接口地址格式不正确，请填写完整的 http(s) 地址')
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new BadRequestException('接口地址只支持 http 或 https')
  }
  return trimmed
}

const toCompletionUrl = (baseUrl: string) =>
  baseUrl.endsWith('/chat/completions') ? baseUrl : `${baseUrl}/chat/completions`

/**
 * 客户端声明了自己能执行哪些工具；一个都没有时整个 tools 字段都不下发，
 * 免得只支持基础对话的兼容接口因为不认识的参数报错。
 * extraTools 是服务端自己执行的 MCP 工具，与客户端工具合并下发。
 */
const toolsPayload = (names: string[] | undefined, extraTools: unknown[] = []) => {
  const tools = [...buildAiToolPayload(names), ...extraTools]
  return tools.length ? { tools, tool_choice: 'auto' as const } : {}
}

/** 上游返回的 tool_call 可能缺 id，回填结果时两边都要用同一个名字 */
const withCallIds = (calls: RawToolCall[], round: number): CompletionToolCall[] =>
  calls.map((call, index) => ({
    id: call.id || `call_${round}_${index}`,
    type: 'function' as const,
    function: {
      name: call.function?.name ?? '',
      arguments: call.function?.arguments?.trim() || '{}',
    },
  }))

const isMcpCall = (call: CompletionToolCall) => call.function.name.startsWith(COROS_TOOL_PREFIX)

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name)

  constructor(
    @InjectRepository(AiSetting)
    private readonly settingRepository: Repository<AiSetting>,
    private readonly contextService: AiContextService,
    private readonly conversationService: AiConversationService,
    private readonly corosService: CorosService,
    private readonly configService: ConfigService,
  ) {}

  private get envApiKey() {
    return this.configService.get<string>('DEEPSEEK_API_KEY', '').trim()
  }

  private get envBaseUrl() {
    return this.configService.get<string>('DEEPSEEK_BASE_URL', '').trim()
  }

  private get envModel() {
    return this.configService.get<string>('DEEPSEEK_MODEL', '').trim()
  }

  /** 返回给前端的配置视图，密钥永远脱敏。 */
  async getSettings(userId: number) {
    const setting = await this.settingRepository.findOne({ where: { userId } })
    const apiKey = setting?.apiKey?.trim() || this.envApiKey

    return {
      provider: setting?.provider || DEFAULT_AI_PROVIDER,
      baseUrl: setting?.baseUrl || this.envBaseUrl || DEFAULT_AI_BASE_URL,
      model: setting?.model || this.envModel || DEFAULT_AI_MODEL,
      temperature: setting ? Number(setting.temperature) : DEFAULT_AI_TEMPERATURE,
      systemPrompt: setting?.systemPrompt ?? '',
      contextScope: this.contextService.normalizeScope(setting?.contextScope),
      hasApiKey: Boolean(apiKey),
      apiKeyPreview: apiKey ? maskApiKey(apiKey) : null,
      keySource: setting?.apiKey ? 'user' : this.envApiKey ? 'env' : 'none',
      defaultSystemPrompt: DEFAULT_AI_SYSTEM_PROMPT,
      updatedAt: setting?.updatedAt ?? null,
    }
  }

  async updateSettings(userId: number, dto: UpdateAiSettingsDto) {
    const setting =
      (await this.settingRepository.findOne({ where: { userId } })) ??
      this.settingRepository.create({
        userId,
        provider: DEFAULT_AI_PROVIDER,
        baseUrl: DEFAULT_AI_BASE_URL,
        model: DEFAULT_AI_MODEL,
        temperature: DEFAULT_AI_TEMPERATURE,
        contextScope: null,
      })

    if (dto.provider !== undefined) setting.provider = dto.provider.trim() || DEFAULT_AI_PROVIDER
    if (dto.baseUrl !== undefined) setting.baseUrl = normalizeBaseUrl(dto.baseUrl)
    if (dto.model !== undefined) setting.model = dto.model.trim() || DEFAULT_AI_MODEL
    if (dto.temperature !== undefined) setting.temperature = dto.temperature
    if (dto.systemPrompt !== undefined) setting.systemPrompt = dto.systemPrompt.trim() || null
    if (dto.contextScope !== undefined) {
      setting.contextScope = this.contextService.normalizeScope(dto.contextScope)
    }

    if (dto.apiKey !== undefined) {
      const apiKey = dto.apiKey.trim()
      if (!isMaskedApiKey(apiKey)) setting.apiKey = apiKey || null
    }

    await this.settingRepository.save(setting)
    return this.getSettings(userId)
  }

  async clearApiKey(userId: number) {
    const setting = await this.settingRepository.findOne({ where: { userId } })
    if (setting) {
      setting.apiKey = null
      await this.settingRepository.save(setting)
    }
    return this.getSettings(userId)
  }

  /** 读取平台数据快照，供设置面板预览。 */
  getContext(user: User, scope?: string[]) {
    return this.contextService.build(user, scope)
  }

  async testConnection(user: User, dto: TestConnectionDto) {
    const setting = await this.settingRepository.findOne({ where: { userId: user.id } })
    const draftKey = dto.apiKey?.trim()
    const apiKey = draftKey && !isMaskedApiKey(draftKey) ? draftKey : setting?.apiKey?.trim() || this.envApiKey
    const baseUrl = normalizeBaseUrl(
      dto.baseUrl?.trim() || setting?.baseUrl || this.envBaseUrl || DEFAULT_AI_BASE_URL,
    )
    const model = dto.model?.trim() || setting?.model || this.envModel || DEFAULT_AI_MODEL

    if (!apiKey) {
      return {
        ok: false,
        model,
        baseUrl,
        latencyMs: 0,
        message: '请先填写 API Key 再测试连接',
      }
    }

    const startedAt = Date.now()
    try {
      const result = await this.requestCompletion(
        {
          model,
          messages: [
            {
              role: 'user',
              content: '这是一次接口连通性测试，请只回复“连接成功”。',
            },
          ],
          temperature: 0,
          max_tokens: 64,
          stream: false,
        },
        { apiKey, baseUrl },
      )

      return {
        ok: true,
        model: result.model ?? model,
        baseUrl,
        latencyMs: Date.now() - startedAt,
        message: `连接成功，模型 ${result.model ?? model} 可用`,
        usage: result.usage ?? null,
        reply: result.content.slice(0, 80),
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : '测试连接失败'
      return {
        ok: false,
        model,
        baseUrl,
        latencyMs: Date.now() - startedAt,
        message,
      }
    }
  }

  /** 用户已连接高驰时，把发现到的 MCP 工具与配套说明一起挂上 */
  private async mcpTools(user: User, dto: ChatDto) {
    if (dto.useMcp === false) return { defs: [] as unknown[], instruction: undefined as string | undefined }

    const defs = await this.corosService.toolDefinitions(user.id)
    if (!defs.length) return { defs: [], instruction: undefined }

    return {
      defs,
      instruction: this.corosService.toolInstruction(defs.map((tool) => tool.function.name)),
    }
  }

  async chat(user: User, dto: ChatDto) {
    const runtime = await this.resolveRuntime(user.id)
    const conversation = await this.resolveConversation(user, dto)

    // 先落用户消息，再取历史（历史末尾即本次提问）
    if (conversation && dto.content?.trim()) {
      await this.conversationService.appendMessage({
        conversation,
        role: AiMessageRole.USER,
        content: dto.content.trim(),
      })
    }

    const mcp = await this.mcpTools(user, dto)
    const { messages, context } = await this.buildMessages(
      user,
      dto,
      runtime,
      conversation?.id,
      mcp.instruction,
    )
    const payload = {
      model: runtime.model,
      temperature: dto.temperature ?? runtime.temperature,
      max_tokens: AI_STREAM_MAX_TOKENS,
      stream: false,
      ...toolsPayload(dto.toolNames, mcp.defs),
    }

    let content = ''
    let model = runtime.model
    let finishReason: string | null = null
    let usage: CompletionUsage | null = null
    let round = 0
    const actions: AiAction[] = []
    const mcpCalls: { name: string; label: string; ok: boolean }[] = []

    // MCP 工具在服务端当场执行并把结果回灌给模型，直到模型不再要求调用
    for (;;) {
      const result = await this.requestCompletion({ ...payload, messages }, runtime)

      model = result.model ?? model
      usage = result.usage ?? usage
      finishReason = result.finishReason ?? null
      if (result.content.trim()) content = content ? `${content}\n\n${result.content}` : result.content

      const calls = withCallIds(result.toolCalls ?? [], round)
      const clientCalls = calls.filter((call) => !isMcpCall(call))
      const serverCalls = calls.filter(isMcpCall)
      actions.push(...normalizeToolCalls(clientCalls))

      if (!serverCalls.length || round >= COROS_MAX_TOOL_ROUNDS) {
        // 客户端工具由用户确认后写入，不再回环；剩下的调用照原样变成待确认卡片
        break
      }

      round += 1
      messages.push({ role: 'assistant', content: result.content, tool_calls: calls })
      for (const call of serverCalls) {
        const exec = await this.runMcpTool(user.id, call)
        mcpCalls.push({ name: exec.alias, label: exec.label, ok: exec.ok })
        messages.push({ role: 'tool', tool_call_id: call.id, content: exec.text })
      }
      for (const call of clientCalls) {
        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: '该操作已提交给用户，用户会在客户端的确认卡片上决定是否写入。',
        })
      }
    }

    // 上游可能返回不认识的函数或残缺参数，校验后才变成客户端可执行的「待确认操作」
    const assistantMessage = conversation
      ? await this.conversationService.appendMessage({
          conversation,
          role: AiMessageRole.ASSISTANT,
          content,
          model,
          contextMeta: this.contextMeta(context),
          actions,
        })
      : null

    return {
      content,
      model,
      finishReason,
      usage,
      context: this.contextMeta(context),
      conversationId: conversation?.id ?? null,
      conversationTitle: conversation?.title ?? null,
      messageId: assistantMessage?.id ?? null,
      actions,
      mcpCalls,
    }
  }

  /** 单个 MCP 工具失败不该整轮中断，把错误原文回填给模型让它自己解释 */
  private async runMcpTool(userId: number, call: CompletionToolCall) {
    try {
      return await this.corosService.execute(userId, call.function.name, call.function.arguments)
    } catch (error) {
      return {
        alias: call.function.name,
        label: call.function.name,
        ok: false,
        text: error instanceof Error ? error.message : '高驰工具调用失败',
      }
    }
  }

  /** 以 SSE 方式把 DeepSeek 的流式输出转发给浏览器。 */
  async streamChat(
    user: User,
    dto: ChatDto,
    request: ExpressRequest,
    response: ExpressResponse,
  ) {
    // 先完成校验：出错时还未写出响应头，异常过滤器可以正常返回 JSON。
    const runtime = await this.resolveRuntime(user.id)
    const conversation = await this.resolveConversation(user, dto)

    if (conversation && dto.content?.trim()) {
      await this.conversationService.appendMessage({
        conversation,
        role: AiMessageRole.USER,
        content: dto.content.trim(),
      })
    }

    const mcp = await this.mcpTools(user, dto)
    const { messages, context } = await this.buildMessages(
      user,
      dto,
      runtime,
      conversation?.id,
      mcp.instruction,
    )
    const contextMeta = this.contextMeta(context)
    const payload = {
      model: runtime.model,
      temperature: dto.temperature ?? runtime.temperature,
      max_tokens: AI_STREAM_MAX_TOKENS,
      stream: true,
      ...toolsPayload(dto.toolNames, mcp.defs),
    }

    response.setHeader('Content-Type', 'text/event-stream; charset=utf-8')
    response.setHeader('Cache-Control', 'no-cache, no-transform')
    response.setHeader('Connection', 'keep-alive')
    response.setHeader('X-Accel-Buffering', 'no')
    if (typeof response.flushHeaders === 'function') response.flushHeaders()

    const send = (event: string, data: unknown) => {
      if (response.writableEnded) return
      response.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
    }

    send('meta', {
      model: runtime.model,
      context: contextMeta,
      conversationId: conversation?.id ?? null,
      conversationTitle: conversation?.title ?? null,
      mcpTools: mcp.defs.length,
    })

    const controller = new AbortController()
    let idleTimer: ReturnType<typeof setTimeout> | null = null
    const resetIdleTimer = () => {
      if (idleTimer) clearTimeout(idleTimer)
      idleTimer = setTimeout(() => controller.abort(), AI_STREAM_IDLE_TIMEOUT_MS)
    }
    const onClientClose = () => {
      if (!response.writableEnded) controller.abort()
    }
    response.on('close', onClientClose)
    request.on('aborted', onClientClose)

    const startedAt = Date.now()
    let content = ''
    let reasoning = ''
    let finishReason: string | null = null
    let usage: CompletionUsage | null = null
    let model = runtime.model
    let persisted = false
    let messageId: number | null = null
    let round = 0
    const actions: AiAction[] = []
    const mcpCalls: { name: string; label: string; ok: boolean }[] = []

    /** 把助手回复写入会话（成功或失败都落库，只写一次） */
    const persistAssistant = async (errorText?: string) => {
      if (!conversation || persisted) return
      persisted = true
      try {
        const saved = await this.conversationService.appendMessage({
          conversation,
          role: AiMessageRole.ASSISTANT,
          content,
          reasoning: reasoning || null,
          model,
          elapsedMs: Date.now() - startedAt,
          contextMeta,
          error: errorText ?? null,
          actions,
        })
        messageId = saved.id
      } catch (error) {
        this.logger.error(
          `AI 回复落库失败：${error instanceof Error ? error.message : String(error)}`,
        )
      }
    }

    /**
     * 读完一轮流：正文与思考实时转发给前端，返回本轮的正文和模型要求的调用。
     * 分片按 index 归位，arguments 是一段一段拼起来的。
     */
    const pumpRound = async (): Promise<{ text: string; calls: CompletionToolCall[] }> => {
      let text = ''
      const toolCallsByIndex = new Map<number, { call: RawToolCall; args: string }>()
      const collectToolCalls = (fragments: ToolCallFragment[]) => {
        for (const fragment of fragments) {
          const index = fragment.index ?? 0
          const existing = toolCallsByIndex.get(index) ?? { call: {}, args: '' }
          if (fragment.id) existing.call.id = fragment.id
          if (fragment.function?.name) existing.call.function = { ...(existing.call.function ?? {}), name: fragment.function.name }
          if (fragment.function?.arguments) existing.args += fragment.function.arguments
          toolCallsByIndex.set(index, existing)
        }
      }
      const collectedToolCalls = (): RawToolCall[] =>
        [...toolCallsByIndex.entries()]
          .sort((left, right) => left[0] - right[0])
          .map(([, item]) => ({
            id: item.call.id,
            function: { name: item.call.function?.name, arguments: item.args },
          }))

      resetIdleTimer()
      const upstream = await this.openStream({ ...payload, messages }, runtime, controller.signal)

      const reader = upstream.body!.getReader()
      const decoder = new TextDecoder('utf-8')
      let buffer = ''

      for (;;) {
        const { value, done } = await reader.read()
        resetIdleTimer()
        if (done) break

        buffer += decoder.decode(value, { stream: true })
        const lines = buffer.split(/\r?\n/)
        buffer = lines.pop() ?? ''

        for (const line of lines) {
          const trimmed = line.trim()
          if (!trimmed || trimmed.startsWith(':')) continue
          if (!trimmed.startsWith('data:')) continue

          const chunkPayload = trimmed.slice(5).trim()
          if (!chunkPayload || chunkPayload === '[DONE]') continue

          let chunk: CompletionChunk
          try {
            chunk = JSON.parse(chunkPayload) as CompletionChunk
          } catch {
            continue
          }

          if (chunk.error?.message) throw new BadGatewayException(chunk.error.message)
          if (chunk.model) model = chunk.model
          if (chunk.usage) usage = chunk.usage

          const choice = chunk.choices?.[0]
          if (!choice) continue

          const reasoningDelta = choice.delta?.reasoning_content
          if (reasoningDelta) {
            reasoning += reasoningDelta
            send('reasoning', { content: reasoningDelta })
          }

          const delta = choice.delta?.content
          if (delta) {
            text += delta
            content += delta
            send('delta', { content: delta })
          }

          if (choice.delta?.tool_calls?.length) collectToolCalls(choice.delta.tool_calls)

          if (choice.finish_reason) finishReason = choice.finish_reason
        }
      }

      return { text, calls: withCallIds(collectedToolCalls(), round) }
    }

    try {
      // 需要高驰数据时，服务端当场执行工具、把结果回灌给模型再问一轮
      for (;;) {
        const { text, calls } = await pumpRound()

        const clientCalls = calls.filter((call) => !isMcpCall(call))
        const serverCalls = calls.filter(isMcpCall)
        actions.push(...normalizeToolCalls(clientCalls))

        if (!serverCalls.length || round >= COROS_MAX_TOOL_ROUNDS) break

        round += 1
        messages.push({ role: 'assistant', content: text, tool_calls: calls })
        for (const call of serverCalls) {
          const exec = await this.runMcpTool(user.id, call)
          mcpCalls.push({ name: exec.alias, label: exec.label, ok: exec.ok })
          send('mcp', { name: exec.alias, label: exec.label, ok: exec.ok })
          messages.push({ role: 'tool', tool_call_id: call.id, content: exec.text })
        }
        for (const call of clientCalls) {
          messages.push({
            role: 'tool',
            tool_call_id: call.id,
            content: '该操作已提交给用户，用户会在客户端的确认卡片上决定是否写入。',
          })
        }
      }

      if (!content.trim() && !reasoning.trim() && !actions.length) {
        await persistAssistant('模型没有返回内容，请重试或更换模型')
        send('error', { message: '模型没有返回内容，请重试或更换模型' })
      } else {
        // 先落库再通知前端，避免前端刷新列表时读不到这条回复
        await persistAssistant()
        for (const [index, action] of actions.entries()) send('action', { index, action })
        send('done', {
          model,
          finishReason,
          usage,
          elapsedMs: Date.now() - startedAt,
          length: content.length,
          messageId,
          actions,
          mcpCalls,
        })
      }
    } catch (error) {
      const aborted = controller.signal.aborted
      const message = aborted
        ? '生成已中断'
        : error instanceof Error
          ? error.message
          : '生成失败'
      if (!aborted) this.logger.error(`AI 流式对话失败：${message}`)
      await persistAssistant(message)
      send('error', { message, partial: content })
    } finally {
      if (idleTimer) clearTimeout(idleTimer)
      response.off('close', onClientClose)
      request.off('aborted', onClientClose)
      if (!response.writableEnded) response.end()
    }
  }

  private contextMeta(context: AiContextSnapshot | null) {
    if (!context) return null
    return {
      generatedAt: context.generatedAt,
      date: context.date,
      weekday: context.weekday,
      scope: context.scope,
      sections: context.sections,
      stats: context.stats,
      length: context.length,
      truncated: context.truncated,
    }
  }

  /**
   * 定位本次对话所属的会话：
   * - 传了 conversationId：用它（校验归属）
   * - 没传但带了 content：自动新建一个会话
   * - 只有 messages：无状态调用，不落库
   */
  private async resolveConversation(user: User, dto: ChatDto) {
    if (dto.conversationId) {
      const conversation = await this.conversationService.getOrFail(user.id, dto.conversationId)
      if (!dto.content?.trim() && !dto.messages?.length) {
        throw new BadRequestException('请输入消息内容')
      }
      return conversation
    }

    if (!dto.content?.trim()) return null
    return this.conversationService.create(user.id)
  }

  private async resolveRuntime(userId: number): Promise<RuntimeConfig> {
    const setting = await this.settingRepository.findOne({ where: { userId } })
    const apiKey = setting?.apiKey?.trim() || this.envApiKey

    if (!apiKey) {
      throw new BadRequestException(
        '尚未配置 DeepSeek API Key，请先在 AI 助手的「设置」中填写密钥',
      )
    }

    return {
      apiKey,
      baseUrl: setting?.baseUrl || this.envBaseUrl || DEFAULT_AI_BASE_URL,
      model: setting?.model || this.envModel || DEFAULT_AI_MODEL,
      temperature: setting ? Number(setting.temperature) : DEFAULT_AI_TEMPERATURE,
      systemPrompt: setting?.systemPrompt?.trim() || DEFAULT_AI_SYSTEM_PROMPT,
      contextScope: this.contextService.normalizeScope(setting?.contextScope),
    }
  }

  private async buildMessages(
    user: User,
    dto: ChatDto,
    runtime: RuntimeConfig,
    conversationId?: number,
    mcpInstruction?: string,
  ) {
    let history: CompletionMessage[]

    if (conversationId) {
      // 会话模式：历史以数据库为准（此时本次提问已经落库，位于末尾）
      history = await this.conversationService.history(conversationId, AI_HISTORY_LIMIT)
    } else {
      history = (dto.messages ?? []).map((message) => ({
        role: message.role,
        content: message.content.slice(0, AI_MESSAGE_MAX_LENGTH),
      }))
      if (dto.content?.trim()) {
        history.push({ role: 'user', content: dto.content.trim().slice(0, AI_MESSAGE_MAX_LENGTH) })
      }
    }

    if (!history.length) throw new BadRequestException('请输入消息内容')

    const systemParts = [runtime.systemPrompt]
    let context: AiContextSnapshot | null = null

    if (dto.useContext !== false) {
      const scope = this.contextService.normalizeScope(dto.contextScope ?? runtime.contextScope)
      if (scope.length) {
        context = await this.contextService.build(user, scope)
        systemParts.push(context.text)
      }
    }

    // 用户可能自定义了 systemPrompt，工具规则单独追加，保证不会被覆盖掉
    systemParts.push(aiToolInstruction(new Date()))
    if (mcpInstruction) systemParts.push(mcpInstruction)

    const messages: CompletionMessage[] = [{ role: 'system', content: systemParts.join('\n\n') }]

    // 只保留最近若干轮，最后一条必须是用户提问
    for (const message of history.slice(-AI_HISTORY_LIMIT)) messages.push(message)
    while (messages.length > 1 && messages[messages.length - 1].role !== 'user') messages.pop()

    return { messages, context }
  }

  private async requestCompletion(
    payload: Record<string, unknown>,
    runtime: Pick<RuntimeConfig, 'apiKey' | 'baseUrl'>,
  ) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), AI_REQUEST_TIMEOUT_MS)

    try {
      const response = await fetch(toCompletionUrl(runtime.baseUrl), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${runtime.apiKey}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      })

      if (!response.ok) {
        const text = await response.text().catch(() => '')
        throw new BadGatewayException(this.describeUpstreamError(response.status, text))
      }

      const body = (await response.json()) as CompletionChunk
      if (body.error?.message) throw new BadGatewayException(body.error.message)

      const content = body.choices?.[0]?.message?.content ?? ''
      return {
        content,
        model: body.model,
        finishReason: body.choices?.[0]?.finish_reason ?? null,
        usage: body.usage ?? null,
        toolCalls: body.choices?.[0]?.message?.tool_calls ?? [],
      }
    } catch (error) {
      if (error instanceof BadGatewayException || error instanceof BadRequestException) throw error
      throw new BadGatewayException(this.describeNetworkError(error))
    } finally {
      clearTimeout(timer)
    }
  }

  private async openStream(
    payload: Record<string, unknown>,
    runtime: RuntimeConfig,
    signal: AbortSignal,
  ) {
    let response: Awaited<ReturnType<typeof fetch>>
    try {
      response = await fetch(toCompletionUrl(runtime.baseUrl), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${runtime.apiKey}`,
          Accept: 'text/event-stream',
        },
        body: JSON.stringify(payload),
        signal,
      })
    } catch (error) {
      if (signal.aborted) throw error
      throw new BadGatewayException(this.describeNetworkError(error))
    }

    if (!response.ok) {
      const text = await response.text().catch(() => '')
      throw new BadGatewayException(this.describeUpstreamError(response.status, text))
    }
    if (!response.body) throw new BadGatewayException('上游接口没有返回流式响应体')

    return response
  }

  private describeUpstreamError(status: number, body: string) {
    let detail = body.slice(0, 300)
    try {
      const parsed = JSON.parse(body) as { error?: { message?: string } }
      if (parsed.error?.message) detail = parsed.error.message
    } catch {
      // 保留原始文本
    }

    if (status === 401) return '接口拒绝了当前 API Key（401），请检查密钥是否填写正确'
    if (status === 402) return '账户余额不足（402），请先充值后再试'
    if (status === 404) return '接口地址不存在（404），请检查「接口地址」与「模型」是否正确'
    if (status === 422) return `请求参数有误（422）：${detail}`
    if (status === 429) return '请求过于频繁（429），请稍后重试'
    if (status >= 500) return `上游服务异常（${status}），请稍后重试`
    return `接口返回 ${status}：${detail || '未知错误'}`
  }

  private describeNetworkError(error: unknown) {
    if (error instanceof Error && error.name === 'AbortError') {
      return '请求超时或已中断，请检查网络后重试'
    }
    const detail = error instanceof Error ? error.message : String(error)
    return `无法连接 AI 接口（${detail}），请检查网络与「接口地址」配置`
  }
}

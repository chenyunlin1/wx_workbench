import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { InjectRepository } from '@nestjs/typeorm'
import type { Request as ExpressRequest } from 'express'
import { createHash } from 'crypto'
import { Repository } from 'typeorm'
import {
  COROS_DISCOVERY_TTL_MS,
  COROS_MAX_CALLS_PER_ROUND,
  COROS_MAX_DISCOVERED_TOOLS,
  COROS_MAX_TOOL_NAME_LENGTH,
  COROS_MAX_TOOL_ROUNDS,
  COROS_MCP_URL,
  COROS_MODEL_TOOL_BUDGET_BYTES,
  COROS_MODEL_TOOL_PRIORITY,
  COROS_REFRESH_LEEWAY_MS,
  COROS_SYNC_STALE_MS,
  COROS_TOOL_PREFIX,
  COROS_TOOL_RESULT_MAX_CHARS,
} from './coros.constants'
import {
  CorosConnection,
  IDLE_COROS_SYNC,
  type CorosSyncReport,
  type CorosToolMeta,
} from './coros-connection.entity'
import { CorosOAuthService, type OAuthMetadata } from './coros-oauth.service'
import { McpClient, McpUnauthorizedError } from './mcp-client'
import { unwrapToolText } from './coros-parsers'

export interface CorosExecution {
  alias: string
  label: string
  ok: boolean
  text: string
}

const aliasOf = (raw: string) => {
  const prefixed = `${COROS_TOOL_PREFIX}${raw.replace(/[^a-zA-Z0-9_-]/g, '_')}`
  if (prefixed.length <= COROS_MAX_TOOL_NAME_LENGTH) return prefixed

  // 上游模型对函数名有 64 字符限制，超长时截断再接一段哈希保证唯一
  const hash = createHash('sha1').update(raw).digest('hex').slice(0, 8)
  return `${prefixed.slice(0, COROS_MAX_TOOL_NAME_LENGTH - hash.length - 1)}_${hash}`
}

const isSchemaNode = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

/** 只在同名 $defs 撞车时用：把子树里的 #/$defs/旧名 改写成新名字 */
const renameRefs = (node: unknown, from: string, to: string) => {
  if (Array.isArray(node)) {
    for (const item of node) renameRefs(item, from, to)
    return
  }
  if (!isSchemaNode(node)) return
  if (node.$ref === `#/$defs/${from}`) node.$ref = `#/$defs/${to}`
  for (const value of Object.values(node)) renameRefs(value, from, to)
}

/**
 * 高驰把复用结构嵌在属性里（properties.course.$defs），但 $ref 写的是 #/$defs/Section，
 * 指针按规范从文档根解析，上游严格校验因此报 "Pointer '/$defs/Section' does not exist"。
 * 把嵌着的 $defs 提到根之后，原有 $ref 不用改写就成立了；同名不同义才需要改名。
 */
const hoistDefinitions = (schema: Record<string, unknown>) => {
  const root: Record<string, unknown> = JSON.parse(JSON.stringify(schema))
  const defs: Record<string, unknown> = {}

  const liftFrom = (node: Record<string, unknown>) => {
    const nested = isSchemaNode(node.$defs) ? node.$defs : null
    if (nested) delete node.$defs

    for (const value of Object.values(node)) {
      if (Array.isArray(value)) {
        for (const item of value) if (isSchemaNode(item)) liftFrom(item)
      } else if (isSchemaNode(value)) {
        liftFrom(value)
      }
    }

    if (!nested) return
    for (const [key, definition] of Object.entries(nested)) {
      let name = key
      if (defs[key] !== undefined && JSON.stringify(defs[key]) !== JSON.stringify(definition)) {
        let index = 2
        while (defs[`${key}_${index}`] !== undefined) index += 1
        name = `${key}_${index}`
        renameRefs(node, key, name)
        renameRefs(definition, key, name)
      }
      defs[name] = definition
    }
  }

  liftFrom(root)
  return Object.keys(defs).length ? { ...root, $defs: defs } : root
}

/** JSON Schema 直接透传给上游模型，只补齐它拒绝接受的空壳 */
const parametersOf = (tool: CorosToolMeta) => {
  const schema = tool.inputSchema
  if (!schema || typeof schema !== 'object' || !schema.properties) {
    return { type: 'object', properties: {}, additionalProperties: false }
  }

  const lifted = hoistDefinitions(schema)
  return {
    type: 'object',
    properties: lifted.properties,
    ...(Array.isArray(schema.required) ? { required: schema.required } : {}),
    ...(isSchemaNode(lifted.$defs) ? { $defs: lifted.$defs } : {}),
  }
}

@Injectable()
export class CorosService {
  private readonly logger = new Logger(CorosService.name)

  constructor(
    @InjectRepository(CorosConnection)
    private readonly repository: Repository<CorosConnection>,
    private readonly oauth: CorosOAuthService,
    private readonly configService: ConfigService,
  ) {}

  private get mcpUrl() {
    return this.configService.get<string>('COROS_MCP_URL', '').trim() || COROS_MCP_URL
  }

  private get apiPrefix() {
    return this.configService.get<string>('API_PREFIX', 'api').replace(/^\/+|\/+$/g, '')
  }

  /** 回调地址优先用显式配置，否则按当前请求的协议与域名推导（本机开发就是 localhost:3000） */
  private redirectUri(request?: ExpressRequest) {
    const configured = this.configService.get<string>('COROS_REDIRECT_URI', '').trim()
    if (configured) return configured.replace(/\/+$/, '')

    const host = request?.get('host') ?? 'localhost:3000'
    const protocol = request?.protocol ?? 'http'
    return `${protocol}://${host}/${this.apiPrefix}/coros/callback`
  }

  /** 授权完成后把浏览器送回前端页面 */
  webOrigin() {
    const configured =
      this.configService.get<string>('COROS_WEB_URL', '').trim() ||
      this.configService.get<string>('CORS_ORIGINS', '').split(',')[0]?.trim() ||
      'http://localhost:5174'
    return configured.replace(/\/+$/, '')
  }

  async status(userId: number) {
    const connection = await this.repository.findOne({ where: { userId } })
    if (!connection) {
      return {
        connected: false,
        endpoint: this.mcpUrl,
        account: null,
        scope: null,
        expiresAt: null,
        toolsSyncedAt: null,
        toolCount: 0,
        sync: IDLE_COROS_SYNC,
      }
    }

    return {
      connected: true,
      endpoint: connection.mcpUrl,
      account: connection.account,
      scope: connection.scope,
      expiresAt: connection.expiresAt,
      toolsSyncedAt: connection.toolsSyncedAt,
      toolCount: (connection.tools ?? []).length,
      sync: {
        status: this.syncStatusOf(connection),
        startedAt: connection.dataSyncStartedAt,
        syncedAt: connection.dataSyncedAt,
        result: connection.dataSyncResult,
      },
    }
  }

  /** 进程重启会把 running 卡死，超过时限就当作没在同步 */
  private syncStatusOf(connection: CorosConnection) {
    if (connection.dataSyncStatus !== 'running') return connection.dataSyncStatus
    const started = connection.dataSyncStartedAt?.getTime() ?? 0
    if (Date.now() - started > COROS_SYNC_STALE_MS) return 'idle'
    return connection.dataSyncStatus
  }

  /** 发起授权：必要时先做一次动态客户端注册，之后复用同一个 client_id */
  async connect(userId: number, request?: ExpressRequest) {
    const mcpUrl = this.mcpUrl
    const metadata = await this.oauth.discover(mcpUrl)
    const redirectUri = this.redirectUri(request)
    const existing = await this.repository.findOne({ where: { userId } })

    let clientId = existing?.clientId ?? null
    if (!clientId || existing?.issuer !== (metadata.issuer ?? '') || existing?.redirectUri !== redirectUri) {
      clientId = await this.oauth.registerClient(metadata, redirectUri)
    }

    const { url, scope } = this.oauth.createAuthorizeUrl({
      metadata,
      clientId,
      redirectUri,
      userId,
    })

    return {
      authorizeUrl: url,
      scope,
      endpoint: mcpUrl,
      callbackUrl: redirectUri,
      connected: Boolean(existing),
    }
  }

  /** 浏览器带着 code 回来：换令牌、落库、顺手把工具清单拉下来 */
  async completeAuthorize(code: string, state: string) {
    const pending = this.oauth.takePending(state)
    const tokens = await this.oauth.exchangeCode({
      metadata: pending.metadata,
      clientId: pending.clientId,
      redirectUri: pending.redirectUri,
      code,
      verifier: pending.verifier,
    })

    const found = await this.repository.findOne({ where: { userId: pending.userId } })
    const connection =
      found ??
      this.repository.create({
        userId: pending.userId,
        issuer: pending.metadata.issuer ?? '',
        clientId: pending.clientId,
        redirectUri: pending.redirectUri,
        mcpUrl: this.mcpUrl,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
        scope: tokens.scope,
        account: tokens.account,
        tools: null,
        toolsSyncedAt: null,
      })

    connection.issuer = pending.metadata.issuer ?? connection.issuer
    connection.clientId = pending.clientId
    connection.redirectUri = pending.redirectUri
    connection.mcpUrl = this.mcpUrl
    connection.accessToken = tokens.accessToken
    connection.refreshToken = tokens.refreshToken ?? connection.refreshToken
    connection.expiresAt = tokens.expiresAt
    connection.scope = tokens.scope ?? connection.scope
    connection.account = tokens.account ?? connection.account

    await this.repository.save(connection)

    // 工具清单决定 AI 能调什么，授权完成就顺手拉一次；失败只提示，不影响连接
    let warning: string | null = null
    try {
      await this.syncTools(pending.userId)
    } catch (error) {
      warning = error instanceof Error ? error.message : '工具清单获取失败'
      this.logger.warn(`高驰授权成功但工具发现失败：${warning}`)
    }

    return {
      userId: pending.userId,
      account: connection.account,
      webOrigin: this.webOrigin(),
      warning,
    }
  }

  async disconnect(userId: number) {
    const connection = await this.repository.findOne({ where: { userId } })
    if (!connection) return { success: true }

    try {
      const metadata = await this.oauth.discover(connection.mcpUrl)
      await this.oauth.revoke(metadata, connection.clientId, [
        connection.accessToken,
        connection.refreshToken ?? '',
      ])
    } catch (error) {
      this.logger.warn(
        `撤销高驰令牌失败，仅清理本地授权：${error instanceof Error ? error.message : String(error)}`,
      )
    }

    await this.repository.delete({ userId })
    return { success: true }
  }

  /** 重新拉一次 tools/list 并缓存 */
  async syncTools(userId: number) {
    const { tools, syncedAt } = await this.discoverTools(userId)
    return { total: tools.length, toolsSyncedAt: syncedAt }
  }

  /** 同步状态机：界面轮询 status，实际拉数据在 CorosSyncService 里 */
  async beginSync(userId: number) {
    const connection = await this.require(userId)
    if (this.syncStatusOf(connection) === 'running') {
      throw new BadRequestException('高驰数据正在同步中，请等当前任务结束')
    }

    connection.dataSyncStatus = 'running'
    connection.dataSyncStartedAt = new Date()
    await this.repository.save(connection)
  }

  async finishSync(userId: number, status: 'done' | 'failed', report: CorosSyncReport) {
    const connection = await this.require(userId)
    connection.dataSyncStatus = status
    connection.dataSyncedAt = new Date()
    connection.dataSyncResult = report
    await this.repository.save(connection)
  }

  /** 同步用：按高驰原始工具名调用，返回去掉外层 JSON 引号的文本报告 */
  async callToolText(userId: number, name: string, args: Record<string, unknown> = {}) {
    const result = await this.withClient(userId, (client) => client.callTool(name, args))
    if (result.isError) {
      throw new Error(result.text.trim().slice(0, 200) || `高驰工具 ${name} 调用失败`)
    }
    return unwrapToolText(result.text)
  }

  private async discoverTools(userId: number) {
    const listed = await this.withClient(userId, (client) => client.listTools())
    const connection = await this.require(userId)

    const cached: CorosToolMeta[] = listed.slice(0, COROS_MAX_DISCOVERED_TOOLS).map((tool) => ({
      name: tool.name,
      alias: aliasOf(tool.name),
      label: tool.title?.trim() || tool.name,
      description: (tool.description ?? '').trim(),
      inputSchema: (tool.inputSchema ?? {}) as Record<string, unknown>,
    }))

    const syncedAt = new Date()
    connection.tools = cached
    connection.toolsSyncedAt = syncedAt
    await this.repository.save(connection)
    return { tools: cached, syncedAt }
  }

  private async require(userId: number) {
    const connection = await this.repository.findOne({ where: { userId } })
    if (!connection) {
      throw new NotFoundException('尚未连接高驰账号，请到「跑步专项」页面完成授权')
    }
    return connection
  }

  private isExpired(connection: CorosConnection) {
    if (!connection.expiresAt) return false
    return connection.expiresAt.getTime() - COROS_REFRESH_LEEWAY_MS < Date.now()
  }

  private async refreshed(connection: CorosConnection) {
    if (!connection.refreshToken) {
      throw new BadRequestException('高驰授权已过期，请重新连接账号')
    }

    let metadata: OAuthMetadata
    try {
      metadata = await this.oauth.discover(connection.mcpUrl)
    } catch (error) {
      this.logger.warn(
        `刷新令牌前发现端点失败，沿用已保存的签发方：${error instanceof Error ? error.message : String(error)}`,
      )
      metadata = {
        issuer: connection.issuer,
        authorizationEndpoint: `${connection.issuer}/oauth2/authorize`,
        tokenEndpoint: `${connection.issuer}/oauth2/token`,
        registrationEndpoint: null,
        revocationEndpoint: `${connection.issuer}/oauth2/revoke`,
        scopesSupported: [],
      }
    }

    const tokens = await this.oauth.refresh(
      metadata,
      connection.clientId,
      connection.refreshToken,
    )

    connection.accessToken = tokens.accessToken
    connection.refreshToken = tokens.refreshToken ?? connection.refreshToken
    connection.expiresAt = tokens.expiresAt
    connection.scope = tokens.scope ?? connection.scope
    await this.repository.save(connection)
  }

  /** 令牌快过期就先刷；服务端仍然拒绝时再刷一次并重放本次调用 */
  private async withClient<T>(userId: number, run: (client: McpClient) => Promise<T>): Promise<T> {
    const connection = await this.require(userId)
    if (this.isExpired(connection)) await this.refreshed(connection)

    const call = () => run(new McpClient(connection.mcpUrl, connection.accessToken))

    try {
      return await call()
    } catch (error) {
      if (!(error instanceof McpUnauthorizedError)) throw error
      await this.refreshed(connection)
      return call()
    }
  }

  /** AI 对话用：已连接就把发现到的工具挂到本次请求上 */
  async toolDefinitions(userId: number) {
    const connection = await this.repository.findOne({ where: { userId } })
    if (!connection) return []

    let tools = connection.tools ?? []
    const stale =
      !tools.length ||
      !connection.toolsSyncedAt ||
      Date.now() - connection.toolsSyncedAt.getTime() > COROS_DISCOVERY_TTL_MS

    if (stale) {
      // 高驰会加工具，清单超过时限就重新拉；失败就沿用旧的，大不了少几个工具
      try {
        tools = (await this.discoverTools(userId)).tools
      } catch (error) {
        this.logger.warn(
          `高驰工具发现失败，沿用缓存的 ${tools.length} 个工具：${error instanceof Error ? error.message : String(error)}`,
        )
      }
    }
    if (!tools.length) return []

    return this.pickModelTools(tools).map((tool) => ({
      type: 'function' as const,
      function: {
        name: tool.alias,
        description: [tool.label, tool.description].filter(Boolean).join('：').slice(0, 600),
        parameters: parametersOf(tool),
      },
    }))
  }

  /**
   * 全量工具的 schema 有 100 KB 左右，每轮都塞进上下文太贵，
   * 所以按「读数据 → 写课表 → 其余按体积」的顺序装到预算为止。
   */
  private pickModelTools(tools: CorosToolMeta[]) {
    const rank = (tool: CorosToolMeta) => {
      const index = COROS_MODEL_TOOL_PRIORITY.indexOf(tool.name)
      return index === -1 ? COROS_MODEL_TOOL_PRIORITY.length : index
    }

    const ordered = [...tools].sort(
      (left, right) =>
        rank(left) - rank(right) ||
        JSON.stringify(left.inputSchema ?? {}).length - JSON.stringify(right.inputSchema ?? {}).length,
    )

    const picked: CorosToolMeta[] = []
    let bytes = 0
    for (const tool of ordered) {
      const size = JSON.stringify({ name: tool.alias, parameters: tool.inputSchema }).length
      if (picked.length && bytes + size > COROS_MODEL_TOOL_BUDGET_BYTES) break
      bytes += size
      picked.push(tool)
    }

    if (picked.length < tools.length) {
      this.logger.debug(
        `高驰 ${tools.length} 个工具中只挂载 ${picked.length} 个（约 ${Math.round(bytes / 1024)} KB）`,
      )
    }
    return picked
  }

  isCorosTool(name?: string) {
    return Boolean(name?.startsWith(COROS_TOOL_PREFIX))
  }

  /** 执行一次服务端工具调用，结果原样回填给模型 */
  async execute(userId: number, alias: string, argsJson: string): Promise<CorosExecution> {
    const connection = await this.require(userId)
    const tool = (connection.tools ?? []).find((item) => item.alias === alias)
    if (!tool) throw new BadRequestException(`未知的 COROS 工具：${alias}`)

    let args: Record<string, unknown> = {}
    if (argsJson.trim()) {
      try {
        const parsed = JSON.parse(argsJson) as unknown
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          args = parsed as Record<string, unknown>
        }
      } catch {
        // 模型偶尔会给出残缺参数，空参数让工具自己报缺什么，比在这里猜更清楚
      }
    }

    try {
      const result = await this.withClient(userId, (client) => client.callTool(tool.name, args))
      const text = result.text.length > COROS_TOOL_RESULT_MAX_CHARS
        ? `${result.text.slice(0, COROS_TOOL_RESULT_MAX_CHARS)}\n（结果过长，已截断）`
        : result.text

      return { alias, label: tool.label, ok: !result.isError, text }
    } catch (error) {
      return {
        alias,
        label: tool.label,
        ok: false,
        text: error instanceof Error ? error.message : '高驰工具调用失败',
      }
    }
  }

  /** 追加到 system 的工具说明，用户自定义提示词覆盖不掉 */
  toolInstruction(labels: string[]) {
    return [
      '# 高驰（COROS）跑步数据',
      `用户已连接高驰账号。以 ${COROS_TOOL_PREFIX} 开头的工具由服务端立即执行并把结果回传给你，不需要用户确认，最多 ${COROS_MAX_TOOL_ROUNDS} 轮、每轮最多 ${COROS_MAX_CALLS_PER_ROUND} 个调用。`,
      '1. 询问跑步记录、配速、距离、心率、睡眠、HRV、血氧、压力、恢复程度、VO2max 等高驰侧数据时，必须先调用工具取真实数据，禁止凭经验或聊天记录猜测。',
      '2. 参数按工具自身的 schema 填写；用户说「最近一周」这类相对时间，按系统提示里的当前时间换算成具体日期。',
      '3. 工具返回失败或数据为空时，直接说明「高驰数据未取到」，不要编造数字。',
      '4. 配速写成 5分32秒/公里 这种形式，距离保留两位小数并以公里为单位。',
      '5. 可用工具：' + labels.join('、') + '。',
    ].join('\n')
  }
}

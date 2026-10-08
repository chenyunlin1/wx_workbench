import { Injectable, Logger } from '@nestjs/common'
import { createHash, randomBytes } from 'crypto'
import {
  COROS_CLIENT_NAME,
  COROS_DISCOVERY_TTL_MS,
  COROS_FALLBACK_AUTH_SERVER,
  COROS_REQUEST_TIMEOUT_MS,
  COROS_SCOPES,
  COROS_STATE_TTL_MS,
} from './coros.constants'

/** 授权服务器元数据里用得到的几个字段 */
export interface OAuthMetadata {
  issuer?: string
  authorizationEndpoint: string
  tokenEndpoint: string
  registrationEndpoint?: string | null
  revocationEndpoint?: string | null
  scopesSupported: string[]
}

export interface OAuthTokenSet {
  accessToken: string
  refreshToken: string | null
  expiresAt: Date | null
  scope: string | null
  /** id_token 里的 sub，只用于界面上标出是哪个高驰账号 */
  account: string | null
}

interface PendingAuth {
  userId: number
  verifier: string
  redirectUri: string
  clientId: string
  metadata: OAuthMetadata
  expiresAt: number
}

interface ProtectedResourceMetadata {
  resource?: string
  authorization_servers?: string[]
}

interface AuthorizationServerMetadata {
  issuer?: string
  authorization_endpoint?: string
  token_endpoint?: string
  registration_endpoint?: string
  revocation_endpoint?: string
  scopes_supported?: string[]
}

interface TokenResponse {
  access_token?: string
  refresh_token?: string
  expires_in?: number
  scope?: string
  id_token?: string
  error?: string
  error_description?: string
}

const base64url = (bytes: Buffer) => bytes.toString('base64url')

/** 只解 id_token 的 payload 当展示标签，不做签名校验 */
const subjectOf = (idToken?: string) => {
  if (!idToken) return null
  try {
    const [, payload] = idToken.split('.')
    if (!payload) return null
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as {
      sub?: string
      nickname?: string
    }
    return claims.sub ?? claims.nickname ?? null
  } catch {
    return null
  }
}

/**
 * 高驰用的是 MCP 规范里的 OAuth 2.1：
 * 端点不写死，先看 MCP 地址的 401 挑战头，再逐级读元数据；
 * 客户端凭据靠动态注册拿，是公共客户端（PKCE，没有 client_secret）。
 */
@Injectable()
export class CorosOAuthService {
  private readonly logger = new Logger(CorosOAuthService.name)
  private cache: { key: string; metadata: OAuthMetadata; expiresAt: number } | null = null
  private readonly pending = new Map<string, PendingAuth>()

  /** 发现结果只跟 MCP 地址有关，缓存起来免得每次连接都跑三趟 HTTP */
  async discover(mcpUrl: string): Promise<OAuthMetadata> {
    if (this.cache && this.cache.key === mcpUrl && this.cache.expiresAt > Date.now()) {
      return this.cache.metadata
    }

    const metadata = await this.fetchMetadata(mcpUrl)
    this.cache = { key: mcpUrl, metadata, expiresAt: Date.now() + COROS_DISCOVERY_TTL_MS }
    return metadata
  }

  private async requestJson<T>(url: string, init: RequestInit, label: string): Promise<T> {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), COROS_REQUEST_TIMEOUT_MS)

    try {
      const response = await fetch(url, { ...init, signal: controller.signal })
      if (!response.ok) {
        const detail = (await response.text().catch(() => '')).slice(0, 200)
        throw new Error(`${label}失败（${response.status}）${detail ? `：${detail}` : ''}`)
      }
      return (await response.json()) as T
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        throw new Error(`${label}超时，请检查网络后重试`)
      }
      if (error instanceof Error && error.message.startsWith(label)) throw error
      throw new Error(
        `无法连接高驰授权服务（${error instanceof Error ? error.message : String(error)}）`,
      )
    } finally {
      clearTimeout(timer)
    }
  }

  private async fetchMetadata(mcpUrl: string): Promise<OAuthMetadata> {
    const endpoint = new URL(mcpUrl)

    // 1) 不带 token 打一下 MCP 地址，从 401 的 WWW-Authenticate 里取元数据地址
    let challenge: string | null = null
    try {
      const probe = await fetch(mcpUrl, {
        method: 'GET',
        headers: { Accept: 'text/event-stream' },
        signal: AbortSignal.timeout(COROS_REQUEST_TIMEOUT_MS),
      })
      challenge = probe.headers.get('www-authenticate')
    } catch (error) {
      this.logger.warn(`探测高驰 MCP 授权头失败：${error instanceof Error ? error.message : String(error)}`)
    }

    // 2) 受保护资源元数据 → 授权服务器；缺头时按 RFC 9728 用同路径推导
    const resourceMetadataUrl =
      /resource_metadata="([^"]+)"/.exec(challenge ?? '')?.[1] ??
      `${endpoint.origin}/.well-known/oauth-protected-resource${endpoint.pathname.replace(/\/$/, '')}`

    let authServer: string
    try {
      const resource = await this.requestJson<ProtectedResourceMetadata>(
        resourceMetadataUrl,
        { method: 'GET', headers: { Accept: 'application/json' } },
        '读取高驰授权信息',
      )
      authServer = resource.authorization_servers?.[0] ?? COROS_FALLBACK_AUTH_SERVER
    } catch (error) {
      this.logger.warn(
        `高驰受保护资源元数据不可用，回落到默认授权服务器：${error instanceof Error ? error.message : String(error)}`,
      )
      authServer = COROS_FALLBACK_AUTH_SERVER
    }

    // 3) 授权服务器元数据；读不到就用 RFC 8414 的标准路径拼一份
    const issuer = authServer.replace(/\/$/, '')
    try {
      const raw = await this.requestJson<AuthorizationServerMetadata>(
        `${issuer}/.well-known/oauth-authorization-server`,
        { method: 'GET', headers: { Accept: 'application/json' } },
        '读取高驰授权服务器',
      )
      if (!raw.authorization_endpoint || !raw.token_endpoint) {
        throw new Error('高驰授权服务器元数据缺少必要的端点')
      }

      return {
        issuer: raw.issuer ?? issuer,
        authorizationEndpoint: raw.authorization_endpoint,
        tokenEndpoint: raw.token_endpoint,
        registrationEndpoint: raw.registration_endpoint ?? null,
        revocationEndpoint: raw.revocation_endpoint ?? null,
        scopesSupported: raw.scopes_supported ?? [...COROS_SCOPES],
      }
    } catch (error) {
      this.logger.warn(
        `高驰授权服务器元数据不可用，使用标准端点兜底：${error instanceof Error ? error.message : String(error)}`,
      )

      return {
        issuer,
        authorizationEndpoint: `${issuer}/oauth2/authorize`,
        tokenEndpoint: `${issuer}/oauth2/token`,
        registrationEndpoint: `${issuer}/connect/register`,
        revocationEndpoint: `${issuer}/oauth2/revoke`,
        scopesSupported: [...COROS_SCOPES],
      }
    }
  }

  /** 动态客户端注册：公共客户端 + PKCE，不需要也不会有 client_secret */
  async registerClient(metadata: OAuthMetadata, redirectUri: string) {
    if (!metadata.registrationEndpoint) {
      throw new Error('高驰授权服务未开放动态客户端注册，请改用手动配置的 client_id')
    }

    const scope = this.scopeOf(metadata)
    const result = await this.requestJson<{ client_id?: string }>(
      metadata.registrationEndpoint,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          client_name: COROS_CLIENT_NAME,
          redirect_uris: [redirectUri],
          grant_types: ['authorization_code', 'refresh_token'],
          response_types: ['code'],
          token_endpoint_auth_method: 'none',
          scope,
        }),
      },
      '注册高驰 MCP 客户端',
    )

    if (!result.client_id) throw new Error('高驰没有返回 client_id，动态注册未完成')
    return result.client_id
  }

  /** 服务端支持哪些 scope 就申请哪些，但 offline_access 必须保住，否则拿不到刷新令牌 */
  private scopeOf(metadata: OAuthMetadata) {
    if (!metadata.scopesSupported.length) return COROS_SCOPES.join(' ')
    const wanted = COROS_SCOPES.filter(
      (scope) => metadata.scopesSupported.includes(scope) || scope === 'offline_access',
    )
    return (wanted.length ? wanted : [...COROS_SCOPES]).join(' ')
  }

  /** 生成一次性的授权跳转：state 同时是 CSRF 校验和取回 PKCE verifier 的钥匙 */
  createAuthorizeUrl(input: {
    metadata: OAuthMetadata
    clientId: string
    redirectUri: string
    userId: number
  }) {
    const verifier = base64url(randomBytes(32))
    const challenge = base64url(createHash('sha256').update(verifier).digest())
    const state = randomBytes(16).toString('hex')
    const scope = this.scopeOf(input.metadata)

    this.gcPending()
    this.pending.set(state, {
      userId: input.userId,
      verifier,
      redirectUri: input.redirectUri,
      clientId: input.clientId,
      metadata: input.metadata,
      expiresAt: Date.now() + COROS_STATE_TTL_MS,
    })

    const url = new URL(input.metadata.authorizationEndpoint)
    url.searchParams.set('response_type', 'code')
    url.searchParams.set('client_id', input.clientId)
    url.searchParams.set('redirect_uri', input.redirectUri)
    url.searchParams.set('scope', scope)
    url.searchParams.set('state', state)
    url.searchParams.set('code_challenge', challenge)
    url.searchParams.set('code_challenge_method', 'S256')

    return { url: url.toString(), state, scope }
  }

  takePending(state: string) {
    const pending = this.pending.get(state)
    this.pending.delete(state)

    if (!pending) throw new Error('授权会话已过期，请重新点击连接')
    if (pending.expiresAt < Date.now()) throw new Error('授权超时，请重新发起连接')
    return pending
  }

  private gcPending() {
    const now = Date.now()
    for (const [state, item] of this.pending) {
      if (item.expiresAt < now) this.pending.delete(state)
    }
  }

  private async postToken(
    metadata: OAuthMetadata,
    clientId: string,
    form: Record<string, string>,
    label: string,
  ): Promise<OAuthTokenSet> {
    const result = await this.requestJson<TokenResponse>(
      metadata.tokenEndpoint,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Accept: 'application/json',
        },
        body: new URLSearchParams(form).toString(),
      },
      label,
    )

    if (result.error) {
      throw new Error(`${label}失败：${result.error_description ?? result.error}`)
    }
    if (!result.access_token) throw new Error(`${label}没有返回访问令牌`)

    return {
      accessToken: result.access_token,
      refreshToken: result.refresh_token ?? null,
      expiresAt: result.expires_in ? new Date(Date.now() + result.expires_in * 1000) : null,
      scope: result.scope ?? null,
      account: subjectOf(result.id_token),
    }
  }

  async exchangeCode(input: {
    metadata: OAuthMetadata
    clientId: string
    redirectUri: string
    code: string
    verifier: string
  }) {
    return this.postToken(
      input.metadata,
      input.clientId,
      {
        grant_type: 'authorization_code',
        code: input.code,
        redirect_uri: input.redirectUri,
        client_id: input.clientId,
        code_verifier: input.verifier,
      },
      '换取高驰访问令牌',
    )
  }

  /** 刷新时未必回新的 refresh_token，空值要保留旧的 */
  async refresh(metadata: OAuthMetadata, clientId: string, refreshToken: string) {
    const token = await this.postToken(
      metadata,
      clientId,
      {
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
        client_id: clientId,
      },
      '刷新高驰授权',
    )

    return token
  }

  /** 解绑时顺手撤销令牌；失败不拦着本地清理 */
  async revoke(metadata: OAuthMetadata, clientId: string, tokens: string[]) {
    if (!metadata.revocationEndpoint) return

    for (const token of tokens.filter(Boolean)) {
      try {
        await fetch(metadata.revocationEndpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ client_id: clientId, token }).toString(),
          signal: AbortSignal.timeout(COROS_REQUEST_TIMEOUT_MS),
        })
      } catch (error) {
        this.logger.warn(
          `撤销高驰令牌失败：${error instanceof Error ? error.message : String(error)}`,
        )
      }
    }
  }
}

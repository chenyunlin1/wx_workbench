import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'

/**
 * tools/list 发现到的一个 MCP 工具。
 * name 是调用时用的原名，alias 是加上前缀、净化过的、发给上游模型的名字。
 */
export interface CorosToolMeta {
  name: string
  alias: string
  label: string
  description: string
  inputSchema: Record<string, unknown>
}

/** 一次同步的产出统计；errors 记录哪个工具在什么参数上失败了 */
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

/** status 与 dashboard 一起带回来的同步状态 */
export interface CorosSyncState {
  status: 'idle' | 'running' | 'done' | 'failed'
  startedAt: string | null
  syncedAt: string | null
  result: CorosSyncReport | null
}

export const IDLE_COROS_SYNC: CorosSyncState = {
  status: 'idle',
  startedAt: null,
  syncedAt: null,
  result: null,
}

/**
 * 每个用户一份高驰授权。
 *
 * access_token/refresh_token 与 AI 的 apiKey 一样只存在服务端、不经接口返回；
 * 工具清单缓存下来，AI 对话时不必每轮都去请求 tools/list。
 */
@Entity('coros_connections')
@Index(['userId'], { unique: true })
export class CorosConnection {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  /** 授权服务器地址；换了签发方就要重新注册客户端 */
  @Column({ name: 'issuer', type: 'varchar', length: 255 })
  issuer: string

  /** 动态注册拿到的公共客户端 ID（没有 secret） */
  @Column({ name: 'client_id', type: 'varchar', length: 128 })
  clientId: string

  @Column({ name: 'redirect_uri', type: 'varchar', length: 255 })
  redirectUri: string

  @Column({ name: 'mcp_url', type: 'varchar', length: 255 })
  mcpUrl: string

  @Column({ name: 'access_token', type: 'text' })
  accessToken: string

  @Column({ name: 'refresh_token', type: 'text', nullable: true })
  refreshToken: string | null

  @Column({ name: 'expires_at', type: 'datetime', nullable: true })
  expiresAt: Date | null

  @Column({ type: 'varchar', length: 255, nullable: true })
  scope: string | null

  /** id_token 里的 sub，只用来在界面上标出「连的是哪个高驰账号」 */
  @Column({ type: 'varchar', length: 127, nullable: true })
  account: string | null

  @Column({ type: 'json', nullable: true, comment: 'tools/list 发现结果缓存' })
  tools: CorosToolMeta[] | null

  @Column({ name: 'tools_synced_at', type: 'datetime', nullable: true })
  toolsSyncedAt: Date | null

  /** idle | running | done | failed，同步在后台跑，界面靠轮询这个字段 */
  @Column({ name: 'data_sync_status', type: 'varchar', length: 16, default: 'idle' })
  dataSyncStatus: string

  @Column({ name: 'data_sync_started_at', type: 'datetime', nullable: true })
  dataSyncStartedAt: Date | null

  @Column({ name: 'data_synced_at', type: 'datetime', nullable: true })
  dataSyncedAt: Date | null

  @Column({ type: 'json', nullable: true, comment: '最近一次同步的统计与失败明细' })
  dataSyncResult: CorosSyncReport | null

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

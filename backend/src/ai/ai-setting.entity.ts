import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'
import { decimalTransformer } from '../entities/decimal.transformer'
import {
  DEFAULT_AI_BASE_URL,
  DEFAULT_AI_MODEL,
  DEFAULT_AI_PROVIDER,
  type AiContextScope,
} from './ai.constants'

/**
 * 每个用户一份 AI 助手配置。
 * apiKey 只在服务端读写，接口返回时一律脱敏。
 */
@Entity('ai_settings')
@Index(['userId'], { unique: true })
export class AiSetting {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ type: 'varchar', length: 32, default: DEFAULT_AI_PROVIDER })
  provider: string

  @Column({ name: 'api_key', type: 'varchar', length: 255, nullable: true })
  apiKey: string | null

  @Column({ name: 'base_url', type: 'varchar', length: 255, default: DEFAULT_AI_BASE_URL })
  baseUrl: string

  @Column({ type: 'varchar', length: 64, default: DEFAULT_AI_MODEL })
  model: string

  @Column({
    type: 'decimal',
    precision: 3,
    scale: 2,
    default: 0.7,
    transformer: decimalTransformer,
  })
  temperature: number

  @Column({ name: 'system_prompt', type: 'text', nullable: true })
  systemPrompt: string | null

  @Column({ name: 'context_scope', type: 'simple-array', nullable: true })
  contextScope: AiContextScope[] | null

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

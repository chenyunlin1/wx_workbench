import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm'
import type { AiAction } from './ai-tools'
import { AiConversation } from './ai-conversation.entity'

export enum AiMessageRole {
  USER = 'user',
  ASSISTANT = 'assistant',
}

/** 会话中的一条消息（system 与数据快照不落库） */
@Entity('ai_messages')
@Index(['conversationId', 'id'])
export class AiMessage {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'conversation_id' })
  conversationId: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ type: 'enum', enum: AiMessageRole })
  role: AiMessageRole

  @Column({ type: 'text' })
  content: string

  @Column({ type: 'text', nullable: true, comment: '推理模型的思考过程' })
  reasoning: string | null

  @Column({ type: 'varchar', length: 64, nullable: true })
  model: string | null

  @Column({ type: 'json', nullable: true, comment: 'AI 提议的写操作及其执行结果' })
  actions: AiAction[] | null

  @Column({ name: 'elapsed_ms', type: 'int', nullable: true })
  elapsedMs: number | null

  @Column({ name: 'context_meta', type: 'json', nullable: true, comment: '本次携带的数据快照概览' })
  contextMeta: unknown | null

  @Column({ type: 'varchar', length: 255, nullable: true })
  error: string | null

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @ManyToOne(() => AiConversation, (conversation) => conversation.messages, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'conversation_id' })
  conversation: AiConversation
}

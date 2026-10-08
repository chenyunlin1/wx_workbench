import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'
import { User } from '../entities/user.entity'
import { AiMessage } from './ai-message.entity'

/** AI 助手的一次会话 */
@Entity('ai_conversations')
@Index(['userId', 'lastMessageAt'])
export class AiConversation {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ type: 'varchar', length: 80, default: '新对话' })
  title: string

  @Column({ type: 'varchar', length: 64, nullable: true, comment: '最近一次使用的模型' })
  model: string | null

  @Column({ name: 'last_message_at', type: 'datetime', nullable: true })
  lastMessageAt: Date | null

  @Column({ name: 'title_edited', type: 'boolean', default: false, comment: '用户是否手动改过标题' })
  titleEdited: boolean

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User

  @OneToMany(() => AiMessage, (message) => message.conversation)
  messages: AiMessage[]
}

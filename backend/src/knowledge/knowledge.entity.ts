import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'

export enum KnowledgeType {
  NOTE = 'note',
  QA = 'qa',
}

@Entity('knowledge_items')
@Index(['userId', 'updatedAt'])
export class Knowledge {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ type: 'enum', enum: KnowledgeType, default: KnowledgeType.NOTE })
  type: KnowledgeType

  @Column({ type: 'varchar', length: 255 })
  title: string

  @Column({ type: 'text' })
  content: string

  @Column({ type: 'simple-array', nullable: true })
  tags: string[] | null

  @Column({ name: 'is_learned', type: 'boolean', default: false })
  isLearned: boolean

  @Column({ type: 'int', default: 0 })
  views: number

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date

  @Column({ name: 'user_id' })
  userId: number
}
import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm'

@Entity('ops_commands')
@Index(['userId'])
export class OpsCommand {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ length: 120 })
  title: string

  @Column({ type: 'text' })
  command: string

  @Column({ type: 'text', nullable: true })
  description: string | null

  @Column({ length: 40, default: '其他' })
  category: string

  @Column({ name: 'user_id' })
  userId: number

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

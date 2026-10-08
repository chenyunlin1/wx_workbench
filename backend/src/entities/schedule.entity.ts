import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'
import { User } from './user.entity'

export enum SchedulePriority {
  HIGH = 'high',
  MEDIUM = 'medium',
  LOW = 'low',
}

@Entity('schedules')
@Index(['userId', 'startTime'])
export class Schedule {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ type: 'varchar', length: 160 })
  title: string

  @Column({ type: 'text', nullable: true })
  description: string | null

  @Column({ name: 'start_time', type: 'datetime' })
  startTime: Date

  @Column({ name: 'end_time', type: 'datetime', nullable: true })
  endTime: Date | null

  @Column({ type: 'varchar', length: 40, default: '日程' })
  category: string

  @Column({ type: 'enum', enum: SchedulePriority, default: SchedulePriority.MEDIUM })
  priority: SchedulePriority

  @Column({ name: 'is_remind', type: 'boolean', default: false })
  isRemind: boolean

  @Column({ name: 'remind_before', type: 'int', nullable: true })
  remindBefore: number | null

  @Column({ default: false })
  completed: boolean

  @Column({ name: 'user_id' })
  userId: number

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date

  @ManyToOne(() => User, (user) => user.schedules, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}

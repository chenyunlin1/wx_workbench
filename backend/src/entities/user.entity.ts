import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'
import { UserRole } from './enums'
import { Schedule } from './schedule.entity'
import { Habit } from './habit.entity'
import { LearningTask } from './learning-task.entity'
import { Interview } from './interview.entity'
import { Finance } from './finance.entity'
import { Health } from './health.entity'
import { ShoppingItem } from './shopping-item.entity'

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ unique: true, length: 64 })
  username: string

  @Column({ type: 'varchar', nullable: true, length: 64 })
  nickname: string | null

  @Column({ select: false })
  password: string

  /** 支持 http(s) 图片地址或 data:image/...;base64 数据 URL（客户端压缩到 256px 内） */
  @Column({ type: 'mediumtext', nullable: true })
  avatar: string | null

  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role: UserRole

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date

  @OneToMany(() => Schedule, (schedule) => schedule.user)
  schedules: Schedule[]

  @OneToMany(() => Habit, (habit) => habit.user)
  habits: Habit[]

  @OneToMany(() => LearningTask, (task) => task.user)
  learningTasks: LearningTask[]

  @OneToMany(() => Interview, (interview) => interview.user)
  interviews: Interview[]

  @OneToMany(() => Finance, (finance) => finance.user)
  finances: Finance[]

  @OneToMany(() => Health, (health) => health.user)
  healthRecords: Health[]

  @OneToMany(() => ShoppingItem, (item) => item.user)
  shoppingItems: ShoppingItem[]
}
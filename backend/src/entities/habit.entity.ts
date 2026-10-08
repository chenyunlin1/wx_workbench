import { Column, Entity, JoinColumn, ManyToOne, OneToMany, PrimaryGeneratedColumn } from 'typeorm'
import { HabitRecord } from './habit-record.entity'
import { User } from './user.entity'

@Entity('habits')
export class Habit {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ length: 80 })
  name: string

  @Column({ length: 32, default: '✨' })
  icon: string

  @Column({ name: 'streak_days', type: 'int', default: 0 })
  streakDays: number

  @Column({ name: 'user_id' })
  userId: number

  @ManyToOne(() => User, (user) => user.habits, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User

  @OneToMany(() => HabitRecord, (record) => record.habit)
  records: HabitRecord[]
}
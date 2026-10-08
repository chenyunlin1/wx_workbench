import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn, Unique } from 'typeorm'
import { Habit } from './habit.entity'

@Entity('habit_records')
@Unique(['habitId', 'checkInDate'])
export class HabitRecord {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'habit_id' })
  habitId: number

  @Column({ name: 'check_in_date', type: 'date' })
  checkInDate: string

  @ManyToOne(() => Habit, (habit) => habit.records, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'habit_id' })
  habit: Habit
}
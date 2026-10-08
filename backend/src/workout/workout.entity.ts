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
import { decimalTransformer } from '../entities/decimal.transformer'
import { User } from '../entities/user.entity'

export enum WorkoutType {
  RUNNING = 'running',
  STRENGTH = 'strength',
  CYCLING = 'cycling',
  SWIMMING = 'swimming',
  YOGA = 'yoga',
  HIIT = 'hiit',
  WALKING = 'walking',
  OTHER = 'other',
}

export enum WorkoutIntensity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
}

/** 健身训练记录 */
@Entity('workouts')
@Index(['userId', 'workoutDate'])
export class Workout {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ type: 'enum', enum: WorkoutType, default: WorkoutType.STRENGTH })
  type: WorkoutType

  @Column({ type: 'varchar', length: 120, nullable: true, comment: '训练名称，可选' })
  title: string | null

  @Column({ type: 'int', default: 0, comment: '时长（分钟）' })
  duration: number

  @Column({ type: 'int', nullable: true, comment: '消耗（千卡）' })
  calories: number | null

  @Column({
    type: 'decimal',
    precision: 6,
    scale: 2,
    nullable: true,
    transformer: decimalTransformer,
    comment: '距离（公里）',
  })
  distance: number | null

  @Column({ type: 'enum', enum: WorkoutIntensity, default: WorkoutIntensity.MEDIUM })
  intensity: WorkoutIntensity

  @Column({ name: 'workout_date', type: 'datetime' })
  workoutDate: Date

  @Column({ type: 'text', nullable: true })
  note: string | null

  @Column({ name: 'user_id' })
  userId: number

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}

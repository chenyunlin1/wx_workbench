import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm'
import { LearningStatus } from './enums'
import { User } from './user.entity'

@Entity('learning_tasks')
export class LearningTask {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ length: 180 })
  title: string

  @Column({ type: 'int', default: 0, comment: '学习时长（分钟）' })
  duration: number

  @Column({ type: 'enum', enum: LearningStatus, default: LearningStatus.TODO })
  status: LearningStatus

  @Column({ name: 'user_id' })
  userId: number

  @ManyToOne(() => User, (user) => user.learningTasks, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}
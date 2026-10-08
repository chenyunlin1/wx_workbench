import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm'
import { InterviewStatus } from './enums'
import { User } from './user.entity'

@Entity('interviews')
export class Interview {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ length: 120 })
  company: string

  @Column({ length: 120 })
  position: string

  @Column({ name: 'interview_time', type: 'datetime' })
  interviewTime: Date

  @Column({ type: 'enum', enum: InterviewStatus, default: InterviewStatus.PENDING })
  status: InterviewStatus

  @Column({ name: 'user_id' })
  userId: number

  @ManyToOne(() => User, (user) => user.interviews, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}
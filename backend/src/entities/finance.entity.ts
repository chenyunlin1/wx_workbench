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
import { decimalTransformer } from './decimal.transformer'
import { FinanceType } from './enums'
import { User } from './user.entity'

@Entity('finances')
@Index(['userId', 'recordDate'])
export class Finance {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ type: 'enum', enum: FinanceType })
  type: FinanceType

  @Column({ type: 'decimal', precision: 10, scale: 2, transformer: decimalTransformer })
  amount: number

  @Column({ type: 'varchar', length: 80 })
  category: string

  @Column({ type: 'varchar', length: 255, nullable: true })
  remark: string | null

  @Column({ name: 'date', type: 'datetime' })
  recordDate: Date

  @Column({ name: 'user_id' })
  userId: number

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date

  @ManyToOne(() => User, (user) => user.finances, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}

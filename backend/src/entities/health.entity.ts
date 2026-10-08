import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm'
import { decimalTransformer } from './decimal.transformer'
import { User } from './user.entity'

@Entity('health_records')
export class Health {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ type: 'decimal', precision: 6, scale: 2, transformer: decimalTransformer })
  weight: number

  @Column({ name: 'record_date', type: 'date' })
  recordDate: string

  @Column({ name: 'user_id' })
  userId: number

  @ManyToOne(() => User, (user) => user.healthRecords, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}
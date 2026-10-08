import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm'
import { decimalTransformer } from './decimal.transformer'
import { ShoppingStatus } from './enums'
import { User } from './user.entity'

@Entity('shopping_items')
export class ShoppingItem {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ length: 160 })
  name: string

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0, transformer: decimalTransformer })
  price: number

  @Column({ type: 'enum', enum: ShoppingStatus, default: ShoppingStatus.PENDING })
  status: ShoppingStatus

  @Column({ name: 'user_id' })
  userId: number

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @ManyToOne(() => User, (user) => user.shoppingItems, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User
}
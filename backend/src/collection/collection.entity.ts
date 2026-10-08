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
import { User } from '../entities/user.entity'

export enum CollectionType {
  BOOK = 'book',
  MOVIE = 'movie',
  MUSIC = 'music',
}

export enum CollectionStatus {
  WISH = 'wish',
  DOING = 'doing',
  DONE = 'done',
}

/** 书影音收藏 */
@Entity('collections')
@Index(['userId', 'type'])
@Index(['userId', 'createdAt'])
export class Collection {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ type: 'enum', enum: CollectionType, default: CollectionType.BOOK })
  type: CollectionType

  @Column({ type: 'varchar', length: 180 })
  title: string

  @Column({ type: 'enum', enum: CollectionStatus, default: CollectionStatus.WISH })
  status: CollectionStatus

  @Column({ type: 'tinyint', nullable: true, comment: '评分 1-5' })
  rating: number | null

  @Column({ name: 'release_year', type: 'int', nullable: true, comment: '出版/上映/发行年份' })
  year: number | null

  @Column({ name: 'cover_url', type: 'varchar', length: 500, nullable: true })
  coverUrl: string | null

  @Column({ type: 'text', nullable: true, comment: '短评' })
  comment: string | null

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

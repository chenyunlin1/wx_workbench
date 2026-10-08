import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'

/** 快照类型：不是按天累积、只是「此刻是这样」的数据 */
export type CorosSnapshotKind = 'profile' | 'fitness' | 'recovery' | 'schedule' | 'devices'

/**
 * 高驰侧的「当前状态」，一个类型一行，整体覆盖。
 *
 * 这些面板字段少但形状最容易被高驰改（比如成绩预测多一个项目），
 * 存 JSON 比为了三五个数字加一张宽表更划算；解析失败时原始文本也留在 payload.raw 里。
 */
@Entity('coros_snapshots')
@Index(['userId', 'kind'], { unique: true })
export class CorosSnapshot {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ type: 'varchar', length: 32 })
  kind: CorosSnapshotKind

  @Column({ type: 'json' })
  payload: Record<string, unknown>

  @Column({ name: 'synced_at', type: 'datetime' })
  syncedAt: Date

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

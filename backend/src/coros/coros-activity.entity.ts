import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'
import { decimalTransformer } from '../entities/decimal.transformer'

/** 高驰的运动大类：只用来选图标和过滤，原始 code 另存一列 */
export type CorosSportCategory = 'running' | 'cycling' | 'swimming' | 'strength' | 'other'

/**
 * 从 MCP 文本报告解析出的单次运动。
 *
 * labelId 是高驰侧的稳定主键，同步按它幂等覆盖；
 * 详细字段（训练负荷、步频、功率…）要额外调 getActivityDetail 才有，
 * 所以 detailSyncedAt 单独标记，避免每次同步都重复请求。
 */
@Entity('coros_activities')
@Index(['userId', 'labelId'], { unique: true })
@Index(['userId', 'activityDate'])
export class CorosActivity {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ name: 'label_id', type: 'varchar', length: 64 })
  labelId: string

  @Column({ name: 'sport_type', type: 'int', nullable: true })
  sportType: number | null

  @Column({ name: 'sport_name', type: 'varchar', length: 64, nullable: true })
  sportName: string | null

  @Column({ type: 'varchar', length: 16, default: 'other' })
  category: CorosSportCategory

  @Column({ name: 'activity_date', type: 'date' })
  activityDate: string

  @Column({ name: 'start_timestamp', type: 'int', nullable: true })
  startTimestamp: number | null

  @Column({ name: 'end_timestamp', type: 'int', nullable: true })
  endTimestamp: number | null

  @Column({ type: 'varchar', length: 120, nullable: true, comment: '课程名，高驰放在 Location 字段里' })
  name: string | null

  @Column({ name: 'duration_seconds', type: 'int', default: 0 })
  durationSeconds: number

  @Column({
    name: 'distance_km',
    type: 'decimal',
    precision: 7,
    scale: 2,
    nullable: true,
    transformer: decimalTransformer,
  })
  distanceKm: number | null

  @Column({ name: 'pace_seconds', type: 'int', nullable: true, comment: '平均配速，秒/公里' })
  paceSeconds: number | null

  @Column({
    name: 'speed_kmh',
    type: 'decimal',
    precision: 6,
    scale: 2,
    nullable: true,
    transformer: decimalTransformer,
  })
  speedKmh: number | null

  @Column({ name: 'avg_hr', type: 'int', nullable: true })
  avgHr: number | null

  @Column({ name: 'calories', type: 'int', nullable: true })
  calories: number | null

  @Column({ name: 'sets', type: 'int', nullable: true, comment: '力量训练的组数' })
  sets: number | null

  @Column({ name: 'training_load', type: 'int', nullable: true, comment: '训练负荷 TL' })
  trainingLoad: number | null

  @Column({ name: 'avg_cadence', type: 'int', nullable: true })
  avgCadence: number | null

  @Column({ name: 'avg_power', type: 'int', nullable: true })
  avgPower: number | null

  @Column({ name: 'elevation_gain', type: 'int', nullable: true })
  elevationGain: number | null

  @Column({ name: 'best_km_seconds', type: 'int', nullable: true, comment: '最快一公里，秒' })
  bestKmSeconds: number | null

  @Column({ name: 'training_focus', type: 'varchar', length: 32, nullable: true })
  trainingFocus: string | null

  @Column({ name: 'performance', type: 'varchar', length: 32, nullable: true })
  performance: string | null

  @Column({ name: 'detail_synced_at', type: 'datetime', nullable: true })
  detailSyncedAt: Date | null

  @Column({ type: 'text', nullable: true, comment: '原始文本报告，字段不够用时从这里补' })
  raw: string | null

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

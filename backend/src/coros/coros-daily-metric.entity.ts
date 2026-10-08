import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm'
import { decimalTransformer } from '../entities/decimal.transformer'

/**
 * 一天一行的健康与训练负荷汇总。
 *
 * 高驰的每日数据散在 6 个工具里（日常健康、睡眠、平均心率、静息心率、压力、HRV、训练负荷），
 * 同步时按「谁后到谁覆盖自己的字段」合并到同一行，所以列都可空。
 * 睡眠与 HRV 的日期按「醒来那天」计，与高驰 App 一致。
 */
@Entity('coros_daily_metrics')
@Index(['userId', 'day'], { unique: true })
export class CorosDailyMetric {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ type: 'date' })
  day: string

  @Column({ type: 'int', nullable: true })
  steps: number | null

  @Column({ type: 'int', nullable: true, comment: '日常消耗（千卡）' })
  calories: number | null

  @Column({ name: 'exercise_minutes', type: 'int', nullable: true })
  exerciseMinutes: number | null

  @Column({ name: 'stress_avg', type: 'int', nullable: true })
  stressAvg: number | null

  @Column({ name: 'stress_level', type: 'varchar', length: 16, nullable: true })
  stressLevel: string | null

  @Column({ name: 'sleep_score', type: 'int', nullable: true, comment: '-1 表示只有小睡' })
  sleepScore: number | null

  @Column({ name: 'sleep_minutes', type: 'int', nullable: true, comment: '含小睡的总睡眠' })
  sleepMinutes: number | null

  @Column({ name: 'main_sleep_minutes', type: 'int', nullable: true })
  mainSleepMinutes: number | null

  @Column({ name: 'deep_ratio', type: 'int', nullable: true })
  deepRatio: number | null

  @Column({ name: 'light_ratio', type: 'int', nullable: true })
  lightRatio: number | null

  @Column({ name: 'rem_ratio', type: 'int', nullable: true })
  remRatio: number | null

  @Column({ name: 'awake_minutes', type: 'int', nullable: true })
  awakeMinutes: number | null

  @Column({ name: 'sleep_window', type: 'varchar', length: 64, nullable: true })
  sleepWindow: string | null

  @Column({ name: 'nap_minutes', type: 'int', nullable: true })
  napMinutes: number | null

  @Column({ name: 'avg_hr', type: 'int', nullable: true })
  avgHr: number | null

  @Column({ name: 'min_hr', type: 'int', nullable: true })
  minHr: number | null

  @Column({ name: 'max_hr', type: 'int', nullable: true })
  maxHr: number | null

  @Column({ name: 'resting_hr', type: 'int', nullable: true })
  restingHr: number | null

  @Column({ name: 'hrv_ms', type: 'int', nullable: true })
  hrvMs: number | null

  @Column({ name: 'hrv_status', type: 'varchar', length: 24, nullable: true })
  hrvStatus: string | null

  @Column({ name: 'hrv_baseline', type: 'int', nullable: true })
  hrvBaseline: number | null

  @Column({ name: 'hrv_low', type: 'int', nullable: true, comment: '正常区间下限' })
  hrvLow: number | null

  @Column({ name: 'hrv_high', type: 'int', nullable: true, comment: '正常区间上限' })
  hrvHigh: number | null

  @Column({ name: 'short_term_load', type: 'int', nullable: true })
  shortTermLoad: number | null

  @Column({ name: 'long_term_load', type: 'int', nullable: true })
  longTermLoad: number | null

  @Column({
    name: 'load_ratio',
    type: 'decimal',
    precision: 4,
    scale: 2,
    nullable: true,
    transformer: decimalTransformer,
  })
  loadRatio: number | null

  @Column({ name: 'load_comment', type: 'varchar', length: 24, nullable: true })
  loadComment: string | null

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

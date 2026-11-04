import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm'

/**
 * 一次运动的 GPS 轨迹。
 *
 * 点序列来自高驰的 FIT 活动文件（record 消息里的经纬度），
 * 入库前已经做过 Ramer–Douglas–Peucker 抽稀，所以这里存的是「够画一条线」的点，
 * 不是原始采样；原始采样动辄上万点，app 画不动、库也白占地方。
 */
@Entity('coros_activity_tracks')
@Index(['userId', 'labelId'], { unique: true })
export class CorosActivityTrack {
  @PrimaryGeneratedColumn()
  id: number

  @Column({ name: 'user_id' })
  userId: number

  @Column({ name: 'label_id', type: 'varchar', length: 64 })
  labelId: string

  /** [[lon,lat],…]，6 位小数（约 0.1m），前端直接按序列折线 */
  @Column({ type: 'mediumtext', comment: '轨迹点 JSON：[[经度,纬度],…]' })
  points: string

  @Column({ name: 'point_count', type: 'int', default: 0 })
  pointCount: number

  /** 列表缩略图用的极简化点（[[lon,lat],…]，十几个点），存的时候算好，列表接口直接带走 */
  @Column({ type: 'mediumtext', comment: '缩略轨迹点 JSON：[[经度,纬度],…]；MySQL 不给 TEXT 列默认值，写入时一律带上' })
  thumb: string

  @Column({ name: 'distance_meters', type: 'int', nullable: true, comment: 'FIT 里的累计距离，用来校验是否取错了活动' })
  distanceMeters: number | null

  @Column({ name: 'start_time', type: 'int', nullable: true, comment: '轨迹起点 unix 秒，用于把 FIT 文件对回活动' })
  startTime: number | null

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date
}

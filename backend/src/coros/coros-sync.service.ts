import { Injectable, Logger, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Between, In, IsNull, LessThan, MoreThanOrEqual, Repository } from 'typeorm'
import {
  COROS_ACTIVITY_DETAIL_LIMIT,
  COROS_HISTORY_EMPTY_WINDOWS,
  COROS_HISTORY_MAX_WINDOWS,
  COROS_HISTORY_WINDOW_DAYS,
  COROS_HRV_CHUNK_DAYS,
  COROS_LAP_ATTEMPT_LIMIT,
  COROS_LAP_BATCH_LIMIT,
  COROS_SYNC_DEFAULT_DAYS,
  COROS_SYNC_MAX_DAYS,
  COROS_TRACK_ATTEMPT_LIMIT,
  COROS_TRACK_BATCH_LIMIT,
  COROS_TRACK_MATCH_TOLERANCE_SECONDS,
  COROS_TRACK_MAX_POINTS,
  COROS_TRACK_THUMB_POINTS,
} from './coros.constants'
import { CorosActivity, type CorosSportCategory } from './coros-activity.entity'
import { CorosActivityTrack } from './coros-activity-track.entity'
import { type CorosSyncReport } from './coros-connection.entity'
import { CorosDailyMetric } from './coros-daily-metric.entity'
import { CorosSnapshot, type CorosSnapshotKind } from './coros-snapshot.entity'
import {
  type FitPoint,
  type FitTrack,
  decodeFitTrack,
  simplifyTrack,
  trackDistanceMeters,
  trackKmMarks,
} from './fit-decoder'
import {
  type ParsedActivity,
  type ParsedLapSplit,
  parseActivityDetail,
  parseActivityLapData,
  parseAvgHeartRate,
  parseDailyHealth,
  parseFitnessOverview,
  parseProfile,
  parseRecovery,
  parseRestingHeartRate,
  parseSleepHrv,
  parseSleepOverview,
  parseSportRecords,
  parseStressLevel,
  parseTrainingLoad,
  parseTrainingSchedule,
} from './coros-parsers'
import { CorosAuthExpiredError, CorosService } from './coros.service'

const DAY_MS = 86_400_000

const isoDay = (date: Date) => {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

/** 高驰的日期参数一律是 yyyyMMdd */
const compactDay = (date: Date) => isoDay(date).replace(/-/g, '')

const shiftDays = (date: Date, days: number) => new Date(date.getTime() + days * DAY_MS)

/** 轨迹列是 JSON 文本，历史空值或写坏过的都当「没有缩略图」，不让列表接口整页 500 */
const pairsOf = (text: string | null | undefined): number[][] => {
  if (!text) return []
  try {
    const parsed = JSON.parse(text) as unknown
    return Array.isArray(parsed) ? (parsed as number[][]) : []
  } catch {
    return []
  }
}

/** 分段列同样是 JSON 文本，写坏了就当这条记录没有分段 */
const splitsOf = (text: string | null | undefined): ParsedLapSplit[] => {
  if (!text) return []
  try {
    const parsed = JSON.parse(text) as unknown
    return Array.isArray(parsed) ? (parsed as ParsedLapSplit[]) : []
  } catch {
    return []
  }
}

/** 高驰的 sport type 码表很碎，界面只关心几个大类 */
const categoryOf = (code: number | null, name: string | null): CorosSportCategory => {
  if (code !== null) {
    if (code >= 100 && code <= 106) return 'running'
    if (code >= 200 && code <= 299) return 'cycling'
    if (code >= 300 && code <= 399) return 'swimming'
    if (code === 402 || code === 9901) return 'strength'
  }
  const text = (name ?? '').toLowerCase()
  if (text.includes('run') || text.includes('jog')) return 'running'
  if (text.includes('bike') || text.includes('cycl')) return 'cycling'
  if (text.includes('swim')) return 'swimming'
  if (text.includes('strength')) return 'strength'
  return 'other'
}

@Injectable()
export class CorosSyncService {
  private readonly logger = new Logger(CorosSyncService.name)

  constructor(
    @InjectRepository(CorosActivity)
    private readonly activities: Repository<CorosActivity>,
    @InjectRepository(CorosDailyMetric)
    private readonly dailyRepo: Repository<CorosDailyMetric>,
    @InjectRepository(CorosSnapshot)
    private readonly snapshots: Repository<CorosSnapshot>,
    @InjectRepository(CorosActivityTrack)
    private readonly tracks: Repository<CorosActivityTrack>,
    private readonly coros: CorosService,
  ) {}

  /** 同步要跑十几个工具调用，放到后台执行，界面轮询 status 看进度 */
  async start(userId: number, days?: number, history?: boolean) {
    const span = Math.min(Math.max(days ?? COROS_SYNC_DEFAULT_DAYS, 1), COROS_SYNC_MAX_DAYS)
    await this.coros.beginSync(userId)

    void this.run(userId, span, history ?? false).catch(async (error: unknown) => {
      const message = error instanceof Error ? error.message : String(error)
      const authExpired = error instanceof CorosAuthExpiredError
      if (!authExpired) this.logger.error(`高驰同步异常中断：${message}`)
      else this.logger.warn(`高驰同步提前结束：${message}`)

      // 半途抛出也要把 running 落成终态，否则界面会一直转圈
      const finishedAt = new Date()
      try {
        await this.coros.finishSync(userId, 'failed', {
          days: span,
          from: isoDay(shiftDays(finishedAt, -(span - 1))),
          to: isoDay(finishedAt),
          activities: 0,
          details: 0,
          tracks: 0,
          laps: 0,
          daily: 0,
          snapshots: [],
          errors: [{ tool: authExpired ? 'coros-auth' : 'sync', message }],
          startedAt: finishedAt.toISOString(),
          finishedAt: finishedAt.toISOString(),
          durationMs: 0,
        })
      } catch {
        /* 连接已被删除之类，没有可写的状态行 */
      }
    })

    return { started: true, days: span, history: history ?? false }
  }

  private async run(userId: number, span: number, history: boolean) {
    const startedAt = new Date()
    const from = shiftDays(startedAt, -(span - 1))
    const to = startedAt
    const range = { startDate: compactDay(from), endDate: compactDay(to) }
    const errors: CorosSyncReport['errors'] = []
    let activities = 0
    let details = 0
    let tracks = 0
    let laps = 0
    let daily = 0
    const snapshotKinds: CorosSnapshotKind[] = []

    /** 单个工具失败只记一条错误，其余数据照常用；授权失效则整轮收摊 */
    const step = async <T>(tool: string, args: Record<string, unknown>, parse: (text: string) => T) => {
      try {
        return parse(await this.coros.callToolText(userId, tool, args))
      } catch (error) {
        if (error instanceof CorosAuthExpiredError) throw error
        errors.push({ tool, message: error instanceof Error ? error.message : String(error) })
        return null
      }
    }

    if (history) {
      activities = await this.backfillRecords(userId, errors)
    } else {
      const records =
        (await step('querySportRecords', { ...range, sportTypeCodes: [65535], limit: 200 }, parseSportRecords)) ?? []
      activities = await this.saveActivities(userId, records)
    }
    details = await this.syncActivityDetails(userId, from, to)
    laps = await this.syncActivityLaps(userId, errors)
    tracks = await this.syncActivityTracks(userId)

    const cache = await this.loadDays(userId, from, to)
    const patch = (day: string) => this.patchDay(cache, userId, day)

    const health = await step('queryDailyHealthData', { days: span }, parseDailyHealth)
    if (health) {
      for (const item of health.days) {
        Object.assign(patch(item.day), {
          steps: item.steps,
          calories: item.calories,
          exerciseMinutes: item.exerciseMinutes,
          stressAvg: item.stressAvg,
        })
      }
      // 标题行的静息心率与 HRV 基线是「今天」的，正文里没有对应分段
      if (health.restingHr !== null || health.hrvBaseline !== null) {
        const today = patch(isoDay(new Date()))
        if (health.restingHr !== null) today.restingHr = health.restingHr
        if (health.hrvBaseline !== null) today.hrvBaseline = health.hrvBaseline
      }
    }

    const sleep = await step('querySleepOverview', range, parseSleepOverview)
    for (const item of sleep ?? []) {
      Object.assign(patch(item.day), {
        sleepScore: item.sleepScore,
        sleepMinutes: item.sleepMinutes,
        mainSleepMinutes: item.mainSleepMinutes,
        deepRatio: item.deepRatio,
        lightRatio: item.lightRatio,
        remRatio: item.remRatio,
        awakeMinutes: item.awakeMinutes,
        sleepWindow: item.sleepWindow,
        napMinutes: item.napMinutes,
      })
    }

    const heart = await step('queryAvgHeartRate', range, parseAvgHeartRate)
    for (const item of heart ?? []) {
      Object.assign(patch(item.day), { avgHr: item.avgHr, minHr: item.minHr, maxHr: item.maxHr })
    }

    const resting = await step('queryRestingHeartRate', { days: span }, parseRestingHeartRate)
    for (const item of resting ?? []) {
      if (item.restingHr !== null) patch(item.day).restingHr = item.restingHr
    }

    const stress = await step('queryStressLevel', { days: span }, parseStressLevel)
    for (const item of stress ?? []) {
      Object.assign(patch(item.day), { stressAvg: item.stressAvg, stressLevel: item.stressLevel })
    }

    const load = await step('queryTrainingLoadAssessment', { days: span }, parseTrainingLoad)
    for (const item of load ?? []) {
      Object.assign(patch(item.day), {
        shortTermLoad: item.shortTermLoad,
        longTermLoad: item.longTermLoad,
        loadRatio: item.loadRatio,
        loadComment: item.loadComment,
      })
    }

    // HRV 工具单次最多 7 天，长窗口按周切块
    for (let cursor = 0; cursor < span; cursor += COROS_HRV_CHUNK_DAYS) {
      const chunkFrom = shiftDays(from, cursor)
      const chunkTo = shiftDays(from, Math.min(cursor + COROS_HRV_CHUNK_DAYS - 1, span - 1))
      const hrv = await step(
        'querySleepHrv',
        { startDate: compactDay(chunkFrom), endDate: compactDay(chunkTo) },
        parseSleepHrv,
      )
      for (const item of hrv ?? []) {
        Object.assign(patch(item.day), {
          hrvMs: item.hrvMs,
          hrvStatus: item.hrvStatus,
          hrvBaseline: item.hrvBaseline,
          hrvLow: item.hrvLow,
          hrvHigh: item.hrvHigh,
        })
      }
    }

    try {
      daily = (await this.dailyRepo.save([...cache.values()])).length
    } catch (error) {
      errors.push({ tool: 'database', message: error instanceof Error ? error.message : String(error) })
    }

    const fitness = await step('queryFitnessAssessmentOverview', {}, parseFitnessOverview)
    if (fitness) {
      await this.saveSnapshot(userId, 'fitness', { ...fitness })
      snapshotKinds.push('fitness')
    }

    const recovery = await step('queryRecoveryStatus', {}, parseRecovery)
    if (recovery) {
      await this.saveSnapshot(userId, 'recovery', { ...recovery })
      snapshotKinds.push('recovery')
    }

    const profile = await step('queryUserInfo', {}, parseProfile)
    if (profile) {
      await this.saveSnapshot(userId, 'profile', { ...profile })
      snapshotKinds.push('profile')
    }

    const schedule = await step(
      'queryTrainingSchedule',
      { startDate: compactDay(new Date()), endDate: compactDay(shiftDays(new Date(), 21)) },
      parseTrainingSchedule,
    )
    if (schedule) {
      await this.saveSnapshot(userId, 'schedule', { items: schedule })
      snapshotKinds.push('schedule')
    }

    const devices = await step('queryDevices', {}, (text) => ({ text }))
    if (devices) {
      await this.saveSnapshot(userId, 'devices', { ...devices })
      snapshotKinds.push('devices')
    }

    const finishedAt = new Date()
    const empty = activities === 0 && daily === 0 && snapshotKinds.length === 0
    await this.coros.finishSync(userId, empty ? 'failed' : 'done', {
      days: span,
      from: isoDay(from),
      to: isoDay(to),
      activities,
      details,
      tracks,
      laps,
      daily,
      snapshots: snapshotKinds,
      errors,
      startedAt: startedAt.toISOString(),
      finishedAt: finishedAt.toISOString(),
      durationMs: finishedAt.getTime() - startedAt.getTime(),
    })

    return { activities, details, tracks, laps, daily, snapshots: snapshotKinds.length, errors: errors.length }
  }

  /** 详细数据一条一次调用，只补最近没取过的，避免同步越跑越慢 */
  private async syncActivityDetails(userId: number, from: Date, to: Date) {
    const pending = await this.activities.find({
      where: { userId, activityDate: Between(isoDay(from), isoDay(to)), detailSyncedAt: IsNull() },
      order: { activityDate: 'DESC' },
      take: COROS_ACTIVITY_DETAIL_LIMIT,
    })

    let done = 0
    for (const activity of pending) {
      try {
        const text = await this.coros.callToolText(userId, 'getActivityDetail', {
          labelId: activity.labelId,
          sportType: activity.sportType ?? 100,
        })
        const detail = parseActivityDetail(text)
        Object.assign(activity, {
          trainingLoad: detail.trainingLoad,
          avgCadence: detail.avgCadence,
          avgPower: detail.avgPower,
          elevationGain: detail.elevationGain,
          bestKmSeconds: detail.bestKmSeconds,
          trainingFocus: detail.trainingFocus,
          performance: detail.performance,
          detailSyncedAt: new Date(),
        })
        await this.activities.save(activity)
        done += 1
      } catch (error) {
        if (error instanceof CorosAuthExpiredError) throw error
        this.logger.warn(
          `活动 ${activity.labelId} 详情获取失败：${error instanceof Error ? error.message : String(error)}`,
        )
      }
    }

    return done
  }

  /**
   * 分段数据（每公里配速、心率、爬升）：详情页的配速条与心率曲线靠它。
   * 一条活动一次调用，所以每次同步只补一批，剩下的靠反复下拉慢慢补齐。
   */
  private async syncActivityLaps(userId: number, errors: CorosSyncReport['errors']) {
    const pending = await this.activities.find({
      where: {
        userId,
        category: In(['running', 'cycling']),
        lapsSyncedAt: IsNull(),
        lapAttempts: LessThan(COROS_LAP_ATTEMPT_LIMIT),
      },
      order: { activityDate: 'DESC' },
      take: COROS_LAP_BATCH_LIMIT,
    })

    let done = 0
    for (const activity of pending) {
      activity.lapAttempts += 1
      try {
        const text = await this.coros.callToolText(userId, 'queryActivityLapData', {
          labelId: activity.labelId,
          sportType: activity.sportType ?? 100,
        })
        const lap = parseActivityLapData(text)
        const summary = lap.summary

        activity.maxHr = summary.maxHr
        activity.maxCadence = summary.maxCadence
        activity.avgStrideCm = summary.avgStrideCm
        activity.elevationLoss = summary.elevationLoss
        if (summary.avgHr !== null) activity.avgHr = summary.avgHr
        if (summary.avgCadence !== null) activity.avgCadence = summary.avgCadence
        if (summary.avgPower !== null) activity.avgPower = summary.avgPower
        if (summary.elevationGain !== null) activity.elevationGain = summary.elevationGain
        if (lap.splits.length > 0) {
          activity.splits = JSON.stringify(lap.splits)
          done += 1
        }
        // 高驰不给总步数，用平均步幅从距离反推：7010 m ÷ 0.83 m ≈ 8400 步
        if (activity.steps === null && activity.avgStrideCm !== null && activity.avgStrideCm > 0
          && activity.distanceKm !== null && activity.distanceKm > 0) {
          activity.steps = Math.round((activity.distanceKm * 1000) / (activity.avgStrideCm / 100))
        }
        activity.lapsSyncedAt = new Date()
        await this.activities.save(activity)
      } catch (error) {
        if (error instanceof CorosAuthExpiredError) throw error
        const message = error instanceof Error ? error.message : String(error)
        errors.push({ tool: 'queryActivityLapData', message: `${activity.labelId}：${message}` })
        this.logger.warn(`活动 ${activity.labelId} 分段获取失败：${message}`)
        await this.activities.save(activity)
      }
    }

    return done
  }

  /**
   * 历史回填：一个月一个窗口往前翻，连续空窗够多就认为已经翻到最早的运动。
   * 满 200 条的窗口对半再切一次，免得单月跑太多被 limit 截断。
   */
  private async backfillRecords(userId: number, errors: CorosSyncReport['errors']) {
    let saved = 0
    let emptyStreak = 0
    let end = new Date()

    for (let index = 0; index < COROS_HISTORY_MAX_WINDOWS && emptyStreak < COROS_HISTORY_EMPTY_WINDOWS; index += 1) {
      const start = shiftDays(end, -(COROS_HISTORY_WINDOW_DAYS - 1))
      const records = await this.fetchRecordsInWindow(userId, start, end, 2, errors)
      saved += await this.saveActivities(userId, records)
      emptyStreak = records.length ? 0 : emptyStreak + 1
      end = shiftDays(start, -1)
    }

    return saved
  }

  private async fetchRecordsInWindow(
    userId: number,
    start: Date,
    end: Date,
    depth: number,
    errors: CorosSyncReport['errors'],
  ): Promise<ParsedActivity[]> {
    const args = { startDate: compactDay(start), endDate: compactDay(end), sportTypeCodes: [65535], limit: 200 }

    let records: ParsedActivity[]
    try {
      records = parseSportRecords(await this.coros.callToolText(userId, 'querySportRecords', args))
    } catch (error) {
      if (error instanceof CorosAuthExpiredError) throw error
      errors.push({
        tool: 'querySportRecords',
        message: `${args.startDate}~${args.endDate}：${error instanceof Error ? error.message : String(error)}`,
      })
      return []
    }

    if (records.length < 200 || depth <= 0) return records

    const middle = shiftDays(start, Math.round((end.getTime() - start.getTime()) / DAY_MS / 2))
    const halves = await Promise.all([
      this.fetchRecordsInWindow(userId, start, middle, depth - 1, errors),
      this.fetchRecordsInWindow(userId, shiftDays(middle, 1), end, depth - 1, errors),
    ])
    return [...halves[0], ...halves[1]]
  }

  /**
   * 轨迹逐条补：高驰对 FIT 文件有每日下载限额，所以一次只取一批，
   * 下拉刷新多次就能把历史记录上的线一点点铺满。
   */
  private async syncActivityTracks(userId: number) {
    const pending = await this.activities.find({
      where: {
        userId,
        category: In(['running', 'cycling']),
        trackSyncedAt: IsNull(),
        trackAttempts: LessThan(COROS_TRACK_ATTEMPT_LIMIT),
      },
      order: { activityDate: 'DESC' },
      take: COROS_TRACK_BATCH_LIMIT,
    })

    let done = 0
    for (const activity of pending) {
      activity.trackAttempts += 1
      try {
        const points = await this.fetchTrackPoints(userId, activity)
        if (points.length >= 2) {
          await this.storeTrack(userId, activity.labelId, points)
          done += 1
        }
        // 没轨迹也算取过：室内跑本来就没有 GPS，别一直占着配额重试
        activity.trackSyncedAt = new Date()
      } catch (error) {
        if (error instanceof CorosAuthExpiredError) throw error
        this.logger.warn(
          `活动 ${activity.labelId} 轨迹获取失败：${error instanceof Error ? error.message : String(error)}`,
        )
      }
      await this.activities.save(activity)
    }

    return done
  }

  private async fetchTrackPoints(userId: number, activity: CorosActivity): Promise<FitPoint[]> {
    const args = { labelId: activity.labelId, sportType: activity.sportType ?? 100 }
    const candidates: FitTrack[] = []

    try {
      const { files } = await this.coros.callToolFiles(userId, 'downloadActivityFitFiles', args)
      for (const file of files) {
        const track = decodeFitTrack(file.bytes)
        if (track.points.length >= 2) candidates.push(track)
      }
    } catch (error) {
      if (error instanceof CorosAuthExpiredError) throw error
      this.logger.warn(
        `活动 ${activity.labelId} 的 FIT 附件获取失败，改走下载地址：${error instanceof Error ? error.message : String(error)}`,
      )
    }

    if (!candidates.length) {
      try {
        const text = await this.coros.callToolText(userId, 'queryActivityFitFileDownloadUrls', args)
        for (const url of text.match(/https?:\/\/[^\s"'|，,]+/g) ?? []) {
          try {
            const track = decodeFitTrack(await this.coros.downloadFile(url))
            if (track.points.length >= 2) candidates.push(track)
          } catch (error) {
            this.logger.warn(
              `活动文件下载失败（${url.slice(0, 60)}）：${error instanceof Error ? error.message : String(error)}`,
            )
          }
        }
      } catch (error) {
        if (error instanceof CorosAuthExpiredError) throw error
        this.logger.warn(
          `活动 ${activity.labelId} 的 FIT 地址查询失败：${error instanceof Error ? error.message : String(error)}`,
        )
      }
    }

    if (!candidates.length) return []

    // 一个活动可能回多个文件，挑开始时间对得上的那个
    const target = activity.startTimestamp
    if (target === null) return candidates[0].points

    const matched = candidates.find(
      (item) => item.startTime !== null && Math.abs(item.startTime - target) <= COROS_TRACK_MATCH_TOLERANCE_SECONDS,
    )
    return (matched ?? candidates[0]).points
  }

  private async storeTrack(userId: number, labelId: string, points: FitPoint[]) {
    const simplified = simplifyTrack(points, COROS_TRACK_MAX_POINTS)
    const packed = simplified.map((point) => [Number(point.lon.toFixed(6)), Number(point.lat.toFixed(6))])
    const thumb = simplifyTrack(points, COROS_TRACK_THUMB_POINTS).map((point) => [
      Number(point.lon.toFixed(5)),
      Number(point.lat.toFixed(5)),
    ])
    const current = await this.tracks.findOne({ where: { userId, labelId } })

    await this.tracks.save(
      Object.assign(current ?? this.tracks.create({ userId, labelId }), {
        points: JSON.stringify(packed),
        thumb: JSON.stringify(thumb),
        pointCount: packed.length,
        distanceMeters: Math.round(trackDistanceMeters(points)),
        startTime: points[0].time ?? null,
      }),
    )
  }

  private async saveActivities(userId: number, records: ParsedActivity[]) {
    if (!records.length) return 0

    const existing = await this.activities.find({
      where: { userId, labelId: In(records.map((item) => item.labelId)) },
    })
    const byLabel = new Map(existing.map((item) => [item.labelId, item]))

    const rows = records.map((record) => {
      const current =
        byLabel.get(record.labelId) ?? this.activities.create({ userId, labelId: record.labelId })

      return Object.assign(current, {
        sportType: record.sportType,
        sportName: record.sportName,
        category: categoryOf(record.sportType, record.sportName),
        activityDate: record.activityDate,
        startTimestamp: record.startTimestamp,
        endTimestamp: record.endTimestamp,
        name: record.name,
        durationSeconds: record.durationSeconds,
        distanceKm: record.distanceKm,
        paceSeconds: record.paceSeconds,
        speedKmh: record.speedKmh,
        avgHr: record.avgHr,
        calories: record.calories,
        sets: record.sets,
        startLat: record.startLat,
        startLon: record.startLon,
        raw: record.raw,
      })
    })

    await this.activities.save(rows)
    return rows.length
  }

  private async loadDays(userId: number, from: Date, to: Date) {
    const rows = await this.dailyRepo.find({
      where: { userId, day: Between(isoDay(from), isoDay(to)) },
    })
    return new Map(rows.map((row) => [row.day, row]))
  }

  private patchDay(cache: Map<string, CorosDailyMetric>, userId: number, day: string) {
    let row = cache.get(day)
    if (!row) {
      row = this.dailyRepo.create({ userId, day })
      cache.set(day, row)
    }
    return row
  }

  private async saveSnapshot(userId: number, kind: CorosSnapshotKind, payload: Record<string, unknown>) {
    const current = await this.snapshots.findOne({ where: { userId, kind } })
    await this.snapshots.save(
      Object.assign(current ?? this.snapshots.create({ userId, kind }), { payload, syncedAt: new Date() }),
    )
  }

  /**
   * 跑步记录列表：按月分组并给出月度汇总，形状对齐高驰 app 的记录页。
   * 只回缩略图要用的字段，原始文本报告不外发。
   */
  async activityList(userId: number, category: string) {
    const rows = await this.activities.find({
      where: { userId, category: In([category as CorosSportCategory]) },
      order: { activityDate: 'DESC', startTimestamp: 'DESC' },
      take: 1000,
    })

    const labelIds = rows.map((row) => row.labelId)
    const trackRows = labelIds.length
      ? await this.tracks.find({ where: { userId, labelId: In(labelIds) }, select: ['labelId', 'thumb'] })
      : []
    const thumbs = new Map<string, number[][]>(trackRows.map((row) => [row.labelId, pairsOf(row.thumb)]))

    const months: Array<{
      month: string
      label: string
      count: number
      distanceKm: number
      durationSeconds: number
      items: Array<Record<string, unknown>>
    }> = []
    const index = new Map<string, (typeof months)[number]>()

    let distanceKm = 0
    let durationSeconds = 0

    for (const row of rows) {
      const key = row.activityDate.slice(0, 7)
      let bucket = index.get(key)
      if (!bucket) {
        bucket = {
          month: key,
          label: `${Number(key.slice(0, 4))}年${Number(key.slice(5, 7))}月`,
          count: 0,
          distanceKm: 0,
          durationSeconds: 0,
          items: [],
        }
        index.set(key, bucket)
        months.push(bucket)
      }

      const item = {
        labelId: row.labelId,
        name: row.name,
        sportName: row.sportName,
        activityDate: row.activityDate,
        startTimestamp: row.startTimestamp,
        durationSeconds: row.durationSeconds,
        distanceKm: row.distanceKm,
        paceSeconds: row.paceSeconds,
        avgHr: row.avgHr,
        calories: row.calories,
        elevationGain: row.elevationGain,
        trainingLoad: row.trainingLoad,
        startLat: row.startLat,
        startLon: row.startLon,
        hasTrack: thumbs.has(row.labelId),
        thumb: thumbs.get(row.labelId) ?? [],
      }

      bucket.items.push(item)
      bucket.count += 1
      bucket.distanceKm = Math.round((bucket.distanceKm + (row.distanceKm ?? 0)) * 100) / 100
      bucket.durationSeconds += row.durationSeconds
      distanceKm = Math.round((distanceKm + (row.distanceKm ?? 0)) * 100) / 100
      durationSeconds += row.durationSeconds
    }

    return { total: rows.length, distanceKm, durationSeconds, months }
  }

  /** 详情：整条活动的指标 + 轨迹折线（含公里标记与外接矩形，前端只管画） */
  async activityDetail(userId: number, labelId: string) {
    const activity = await this.activities.findOne({ where: { userId, labelId } })
    if (!activity) throw new NotFoundException('没有找到这条运动记录')

    const stored = await this.tracks.findOne({ where: { userId, labelId } })
    const pairs = stored ? (JSON.parse(stored.points) as Array<[number, number]>) : []
    const points = pairs.map(([lon, lat]) => ({ lon, lat }))

    let bbox: [number, number, number, number] | null = null
    if (points.length) {
      let minLon = Infinity
      let minLat = Infinity
      let maxLon = -Infinity
      let maxLat = -Infinity
      for (const point of points) {
        minLon = Math.min(minLon, point.lon)
        maxLon = Math.max(maxLon, point.lon)
        minLat = Math.min(minLat, point.lat)
        maxLat = Math.max(maxLat, point.lat)
      }
      bbox = [minLon, minLat, maxLon, maxLat]
    }

    const { raw: _raw, splits: _splits, lapsSyncedAt: _laps, lapAttempts: _attempts, ...summary } = activity
    return {
      activity: summary,
      splits: splitsOf(activity.splits),
      track: stored
        ? {
            points,
            kmMarks: trackKmMarks(points),
            bbox,
            pointCount: stored.pointCount,
            distanceMeters: stored.distanceMeters,
            startTime: stored.startTime,
          }
        : null,
    }
  }

  /** 页面一次取齐：已同步的活动、逐日指标与快照，聚合交给前端算 */
  async dashboard(userId: number, days?: number) {
    const span = Math.min(Math.max(days ?? COROS_SYNC_DEFAULT_DAYS, 1), COROS_SYNC_MAX_DAYS)
    const from = shiftDays(new Date(), -(span - 1))

    const [activityRows, daily, snapshots, status] = await Promise.all([
      this.activities.find({
        where: { userId, activityDate: MoreThanOrEqual(isoDay(from)) },
        order: { activityDate: 'ASC', startTimestamp: 'ASC' },
      }),
      this.dailyRepo.find({
        where: { userId, day: Between(isoDay(from), isoDay(new Date())) },
        order: { day: 'ASC' },
      }),
      this.snapshots.find({ where: { userId, kind: In(['fitness', 'recovery', 'profile', 'schedule', 'devices']) } }),
      this.coros.status(userId),
    ])

    const payload = (kind: CorosSnapshotKind) => snapshots.find((item) => item.kind === kind)?.payload ?? null

    return {
      connected: status.connected,
      account: status.account,
      sync: status.sync,
      // raw 是整段文本报告，splits 是分段 JSON，页面用不到，别让它们把响应撑大
      activities: activityRows.map(
        ({ raw, splits, lapsSyncedAt, lapAttempts, userId: _user, createdAt: _c, updatedAt: _u, ...row }) => row,
      ),
      daily: daily.map(({ userId: _user, createdAt: _c, updatedAt: _u, ...row }) => row),
      fitness: payload('fitness'),
      recovery: payload('recovery'),
      profile: payload('profile'),
      schedule: payload('schedule'),
      devices: payload('devices'),
    }
  }
}

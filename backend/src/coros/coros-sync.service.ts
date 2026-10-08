import { Injectable, Logger } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Between, In, IsNull, MoreThanOrEqual, Repository } from 'typeorm'
import {
  COROS_ACTIVITY_DETAIL_LIMIT,
  COROS_HRV_CHUNK_DAYS,
  COROS_SYNC_DEFAULT_DAYS,
  COROS_SYNC_MAX_DAYS,
} from './coros.constants'
import { CorosActivity, type CorosSportCategory } from './coros-activity.entity'
import { type CorosSyncReport } from './coros-connection.entity'
import { CorosDailyMetric } from './coros-daily-metric.entity'
import { CorosSnapshot, type CorosSnapshotKind } from './coros-snapshot.entity'
import {
  type ParsedActivity,
  parseActivityDetail,
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
import { CorosService } from './coros.service'

const DAY_MS = 86_400_000

const isoDay = (date: Date) => {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

/** 高驰的日期参数一律是 yyyyMMdd */
const compactDay = (date: Date) => isoDay(date).replace(/-/g, '')

const shiftDays = (date: Date, days: number) => new Date(date.getTime() + days * DAY_MS)

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
    private readonly coros: CorosService,
  ) {}

  /** 同步要跑十几个工具调用，放到后台执行，界面轮询 status 看进度 */
  async start(userId: number, days?: number) {
    const span = Math.min(Math.max(days ?? COROS_SYNC_DEFAULT_DAYS, 1), COROS_SYNC_MAX_DAYS)
    await this.coros.beginSync(userId)

    void this.run(userId, span).catch((error: unknown) => {
      this.logger.error(`高驰同步异常中断：${error instanceof Error ? error.message : String(error)}`)
    })

    return { started: true, days: span }
  }

  private async run(userId: number, span: number) {
    const startedAt = new Date()
    const from = shiftDays(startedAt, -(span - 1))
    const to = startedAt
    const range = { startDate: compactDay(from), endDate: compactDay(to) }
    const errors: CorosSyncReport['errors'] = []
    let activities = 0
    let details = 0
    let daily = 0
    const snapshotKinds: CorosSnapshotKind[] = []

    /** 单个工具失败只记一条错误，其余数据照常用 */
    const step = async <T>(tool: string, args: Record<string, unknown>, parse: (text: string) => T) => {
      try {
        return parse(await this.coros.callToolText(userId, tool, args))
      } catch (error) {
        errors.push({ tool, message: error instanceof Error ? error.message : String(error) })
        return null
      }
    }

    const records =
      (await step('querySportRecords', { ...range, sportTypeCodes: [65535], limit: 200 }, parseSportRecords)) ?? []
    activities = await this.saveActivities(userId, records)
    details = await this.syncActivityDetails(userId, from, to)

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
      daily,
      snapshots: snapshotKinds,
      errors,
      startedAt: startedAt.toISOString(),
      finishedAt: finishedAt.toISOString(),
      durationMs: finishedAt.getTime() - startedAt.getTime(),
    })

    return { activities, details, daily, snapshots: snapshotKinds.length, errors: errors.length }
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
        this.logger.warn(
          `活动 ${activity.labelId} 详情获取失败：${error instanceof Error ? error.message : String(error)}`,
        )
      }
    }

    return done
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
      // raw 是整段文本报告，页面用不到，别让它把响应撑大
      activities: activityRows.map(({ raw, userId: _user, createdAt: _c, updatedAt: _u, ...row }) => row),
      daily: daily.map(({ userId: _user, createdAt: _c, updatedAt: _u, ...row }) => row),
      fitness: payload('fitness'),
      recovery: payload('recovery'),
      profile: payload('profile'),
      schedule: payload('schedule'),
      devices: payload('devices'),
    }
  }
}

/**
 * 高驰 MCP 的 tools/call 返回的是一整段排版好的文本报告（形如 `Key: value`），
 * 不是结构化 JSON，所以入库前需要在服务端解析一次。
 *
 * 这里全部是纯函数：解析失败只会让对应面板显示「暂无」，不会把同步整体打断，
 * 原始文本另存一份到 raw / payload.raw，将来高驰改格式可以从库里回放重解析。
 */

/** 工具正文本身又是一个 JSON 字符串（带引号和 \n 转义），先剥掉这层壳 */
export const unwrapToolText = (raw: string) => {
  const text = raw.trim()
  if (!text.startsWith('"')) return raw
  try {
    const parsed = JSON.parse(text) as unknown
    return typeof parsed === 'string' ? parsed : raw
  } catch {
    return raw
  }
}

const escapeRe = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

/** 报告里的值一律待在行内（| 只作同行分隔符），所以按「行首键名 → 到行尾或 |」取段 */
const segment = (source: string, key: string) => {
  const pattern = new RegExp(
    `(?:^|[\\r\\n|])\\s*${escapeRe(key)}\\s*(?:\\((?:[^)]*)\\))?\\s*[:：]\\s*([^\\r\\n|]+)`,
    'i',
  )
  return source.match(pattern)?.[1]?.trim() ?? null
}

const numOf = (source: string, key: string) => {
  const raw = segment(source, key)?.replace(/,/g, '')
  const value = raw ? Number(raw.match(/-?\d+(?:\.\d+)?/)?.[0]) : NaN
  return Number.isFinite(value) ? value : null
}

/** "7:05" / "1:11:23" / "48:53" / "7:05 /km" → 秒 */
const clockToSeconds = (value: string | null) => {
  if (!value) return null
  const match = value.trim().match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?/)
  if (!match) return null
  const [, first, second, third] = match
  return third
    ? Number(first) * 3600 + Number(second) * 60 + Number(third)
    : Number(first) * 60 + Number(second)
}

const secondsOf = (source: string, key: string) => clockToSeconds(segment(source, key))

/** "7h 48min" / "9 min" / "1h 2min" / "50 min" → 分钟 */
const minutesOf = (source: string, key: string) => {
  const raw = segment(source, key)
  if (!raw) return null
  const hours = Number(raw.match(/(\d+)\s*h/i)?.[1] ?? 0)
  const minutes = Number(raw.match(/(\d+)\s*min/i)?.[1] ?? 0)
  const plain = Number(raw.match(/^(\d+(?:\.\d+)?)$/)?.[1] ?? NaN)
  const total = hours * 60 + minutes + (Number.isFinite(plain) ? plain : 0)
  return total > 0 ? Math.round(total) : 0
}

const kmOf = (source: string, key: string) => {
  const raw = segment(source, key)
  if (!raw) return null
  const value = Number(raw.replace(/,/g, '').match(/-?\d+(?:\.\d+)?/)?.[0])
  if (!Number.isFinite(value)) return null
  return /\bm\b(?!\/)/i.test(raw) ? Number((value / 1000).toFixed(3)) : value
}

/** 报告里的日期统一是 YYYY-MM-DD，个别工具用 yyyyMMdd */
const isoDay = (value: string | null) => {
  if (!value) return null
  const compact = value.match(/(\d{4})-?(\d{2})-?(\d{2})/)
  return compact ? `${compact[1]}-${compact[2]}-${compact[3]}` : null
}

export interface ParsedActivity {
  labelId: string
  sportType: number | null
  sportName: string
  activityDate: string
  name: string | null
  startTimestamp: number | null
  endTimestamp: number | null
  durationSeconds: number
  distanceKm: number | null
  paceSeconds: number | null
  speedKmh: number | null
  avgHr: number | null
  calories: number | null
  sets: number | null
  raw: string
}

const RECORD_HEAD = /^\s*\d+\.\s+(.+?)\s*[—–-]\s*(\d{4}-\d{2}-\d{2})\s*$/

/** querySportRecords：一条记录一段，段首是 `1. Outdoor Run — 2026-09-30` */
export const parseSportRecords = (text: string): ParsedActivity[] => {
  const records: ParsedActivity[] = []
  let head: { sportName: string; activityDate: string } | null = null
  let body: string[] = []

  const flush = () => {
    if (head) {
      const block = body.join('\n')
      const labelId = segment(block, 'LabelId')
      if (labelId) {
        records.push({
          labelId,
          sportType: numOf(block, 'SportType'),
          sportName: head.sportName,
          activityDate: head.activityDate,
          name: segment(block, 'Location'),
          startTimestamp: Number(block.match(/startTimestamp=(\d+)/)?.[1]) || null,
          endTimestamp: Number(block.match(/endTimestamp=(\d+)/)?.[1]) || null,
          durationSeconds: secondsOf(block, 'Duration') ?? 0,
          distanceKm: kmOf(block, 'Distance'),
          paceSeconds: secondsOf(block, 'Average Pace'),
          speedKmh: numOf(block, 'Average Speed'),
          avgHr: numOf(block, 'Avg HR'),
          calories: numOf(block, 'Calories'),
          sets: numOf(block, 'Sets'),
          raw: block.trim(),
        })
      }
    }
    head = null
    body = []
  }

  for (const line of text.split(/\r?\n/)) {
    const match = line.match(RECORD_HEAD)
    if (match) {
      flush()
      head = { sportName: match[1].trim(), activityDate: match[2] }
      continue
    }
    if (head) body.push(line)
  }
  flush()

  return records
}

export interface ParsedActivityDetail {
  trainingLoad: number | null
  avgCadence: number | null
  avgPower: number | null
  elevationGain: number | null
  bestKmSeconds: number | null
  trainingFocus: string | null
  performance: string | null
  raw: string
}

/** getActivityDetail：补齐列表里没有的训练负荷、步频、功率、爬升 */
export const parseActivityDetail = (text: string): ParsedActivityDetail => {
  const elevation = segment(text, 'Elevation Gain / Loss')
  const performance = segment(text, 'Performance')
  return {
    trainingLoad: numOf(text, 'Training Load'),
    avgCadence: numOf(text, 'Average Cadence'),
    avgPower: numOf(text, 'Average Power'),
    elevationGain: elevation ? Number(elevation.match(/(\d+)\s*m/)?.[1]) || null : null,
    bestKmSeconds: secondsOf(text, 'Best Kilometer'),
    trainingFocus: segment(text, 'Training Focus'),
    // 样本不足时高驰回 "-1"，直接显示会是一个没有含义的 -1
    performance: performance === '-1' ? null : performance,
    raw: text.trim(),
  }
}

export interface ParsedDailyHealth {
  restingHr: number | null
  hrvBaseline: number | null
  days: {
    day: string
    steps: number | null
    calories: number | null
    exerciseMinutes: number | null
    stressAvg: number | null
  }[]
}

/** queryDailyHealthData：标题行是今天的静息心率与 HRV 基线，正文按 `--- 20260930 ---` 分段 */
export const parseDailyHealth = (text: string): ParsedDailyHealth => {
  const header = text.split(/\r?\n/)[0] ?? ''
  const days: ParsedDailyHealth['days'] = []
  let day: string | null = null
  let body: string[] = []

  const flush = () => {
    if (day) {
      const block = body.join('\n')
      days.push({
        day,
        steps: numOf(block, 'Steps'),
        calories: numOf(block, 'Calories'),
        exerciseMinutes: numOf(block, 'Exercise'),
        stressAvg: Number(block.match(/Stress:\s*Avg\s*(\d+)/i)?.[1]) || null,
      })
    }
    day = null
    body = []
  }

  for (const line of text.split(/\r?\n/)) {
    const matched = line.match(/^---\s*(\d{8})\s*---\s*$/)?.[1]
    if (matched) {
      flush()
      day = isoDay(matched)
      continue
    }
    if (day) body.push(line)
  }
  flush()

  return { restingHr: numOf(header, 'Resting HR'), hrvBaseline: numOf(header, 'HRV Baseline'), days }
}

export interface ParsedSleep {
  day: string
  sleepScore: number | null
  sleepMinutes: number | null
  mainSleepMinutes: number | null
  deepRatio: number | null
  lightRatio: number | null
  remRatio: number | null
  awakeMinutes: number | null
  sleepWindow: string | null
  napMinutes: number | null
}

/** querySleepOverview：一天一段，日期是「醒来那天」 */
export const parseSleepOverview = (text: string): ParsedSleep[] => {
  const lines = text.split(/\r?\n/)
  const sections: { day: string; body: string }[] = []

  for (const line of lines) {
    const day = line.match(/^\s*(\d{4}-\d{2}-\d{2})\s*$/)?.[1]
    if (day) sections.push({ day, body: '' })
    else if (sections.length) sections[sections.length - 1].body += `\n${line}`
  }

  return sections.map(({ day, body }) => {
    const row: ParsedSleep = {
      day,
      sleepScore: numOf(body, 'Sleep Score'),
      sleepMinutes: minutesOf(body, 'Daily Sleep'),
      mainSleepMinutes: minutesOf(body, 'Main Sleep'),
      deepRatio: numOf(body, 'Deep Sleep Ratio'),
      lightRatio: numOf(body, 'Light Sleep Ratio'),
      remRatio: numOf(body, 'REM Ratio'),
      awakeMinutes: minutesOf(body, 'Awake Time'),
      sleepWindow: segment(body, 'Main Sleep Window'),
      napMinutes: minutesOf(body, 'Naps Total'),
    }

    // 没戴手表睡觉的那几天，高驰照样回一个 Sleep Score: 0；
    // 当成 0 分会把睡眠趋势线砸到地上，这里按「没有记录」处理。
    if (row.sleepMinutes === null && row.napMinutes === null) {
      row.sleepScore = null
    }

    return row
  })
}

export const parseAvgHeartRate = (text: string) => {
  const rows: { day: string; avgHr: number | null; minHr: number | null; maxHr: number | null }[] = []

  for (const line of text.split(/\r?\n/)) {
    const day = line.match(/^\s*(\d{4}-\d{2}-\d{2})\s*:\s*(.+)$/)?.[1]
    if (!day) continue
    const value = Number(line.match(/:\s*(\d+)\s*bpm/i)?.[1])
    rows.push({
      day,
      avgHr: Number.isFinite(value) ? value : null,
      minHr: Number(line.match(/Min:\s*(\d+)/i)?.[1]) || null,
      maxHr: Number(line.match(/Max:\s*(\d+)/i)?.[1]) || null,
    })
  }

  return rows
}

export const parseRestingHeartRate = (text: string) => {
  const rows: { day: string; restingHr: number | null }[] = []

  for (const line of text.split(/\r?\n/)) {
    const day = line.match(/^\s*(\d{4}-\d{2}-\d{2})\s*:\s*(.+)$/)?.[1]
    if (!day) continue
    const value = Number(line.match(/(\d+)\s*bpm/i)?.[1])
    rows.push({ day, restingHr: Number.isFinite(value) ? value : null })
  }

  return rows
}

export const parseStressLevel = (text: string) => {
  const rows: { day: string; stressAvg: number | null; stressLevel: string | null }[] = []
  let day: string | null = null

  for (const line of text.split(/\r?\n/)) {
    const matched = line.match(/^\s*(\d{4}-\d{2}-\d{2}):?\s*$/)?.[1]
    if (matched) {
      day = matched
      continue
    }
    const value = line.match(/Average Stress:\s*(\d+)\s*(?:\(([^)]*)\))?/i)
    if (value && day) {
      rows.push({ day, stressAvg: Number(value[1]), stressLevel: value[2] ?? null })
    }
  }

  return rows
}

export const parseSleepHrv = (text: string) => {
  // 原始时间序列可能有几万行，评估段落才是面板要的东西
  const assessment = text.split(/Sleep HRV Time Series/i)[0]
  const rows: {
    day: string
    hrvMs: number | null
    hrvStatus: string | null
    hrvBaseline: number | null
    hrvLow: number | null
    hrvHigh: number | null
  }[] = []
  let day: string | null = null

  for (const line of assessment.split(/\r?\n/)) {
    const matched = line.match(/^\s*(\d{4}-\d{2}-\d{2}):?\s*$/)?.[1]
    if (matched) {
      day = matched
      continue
    }
    if (!day) continue

    const avg = line.match(/HRV Avg:\s*(\d+)\s*ms\s*[—–-]?\s*([A-Za-z ]*)/i)
    if (avg) {
      rows.push({
        day,
        hrvMs: Number(avg[1]),
        hrvStatus: avg[2]?.trim() || null,
        hrvBaseline: null,
        hrvLow: null,
        hrvHigh: null,
      })
      continue
    }

    const current = rows[rows.length - 1]
    if (!current || current.day !== day) continue
    const range = line.match(/Normal Range:\s*(\d+)\s*-\s*(\d+)/i)
    if (range) {
      current.hrvLow = Number(range[1])
      current.hrvHigh = Number(range[2])
    }
    const baseline = line.match(/Baseline:\s*(\d+)/i)
    if (baseline) current.hrvBaseline = Number(baseline[1])
  }

  return rows.filter((item) => item.hrvMs !== null)
}

export const parseTrainingLoad = (text: string) => {
  const lines = text.split(/\r?\n/)
  const rows: {
    day: string
    loadComment: string | null
    shortTermLoad: number | null
    longTermLoad: number | null
    loadRatio: number | null
  }[] = []

  for (const line of lines) {
    const day = line.match(/^\s*(\d{4}-\d{2}-\d{2})\s*$/)?.[1]
    if (day) {
      rows.push({ day, loadComment: null, shortTermLoad: null, longTermLoad: null, loadRatio: null })
      continue
    }
    const current = rows[rows.length - 1]
    if (!current) continue

    const comment = line.match(/Comment:\s*(.+)/i)?.[1]
    if (comment) current.loadComment = comment.trim()
    const short = line.match(/Short-Term Load:\s*(\d+)/i)
    if (short) current.shortTermLoad = Number(short[1])
    const long = line.match(/Long-Term Load:\s*(\d+)/i)
    if (long) current.longTermLoad = Number(long[1])
    const ratio = line.match(/Load Ratio:\s*([\d.]+)/i)
    if (ratio) current.loadRatio = Number(ratio[1])
  }

  return rows.filter((item) => item.shortTermLoad !== null)
}

export interface ParsedFitness {
  vo2max: number | null
  runningLevel: number | null
  thresholdPaceSeconds: number | null
  predictions: { label: string; seconds: number | null }[]
}

/** queryFitnessAssessmentOverview：VO2max、跑步等级、阈值配速与四项成绩预测 */
export const parseFitnessOverview = (text: string): ParsedFitness => {
  const predictions: { label: string; seconds: number | null }[] = []
  const pattern = /(\d+\s*km|Half Marathon|Marathon)\s*Prediction:\s*([\d:]+)/gi
  let match: RegExpExecArray | null

  while ((match = pattern.exec(text))) {
    const label = match[1].replace(/\s+/g, ' ').trim()
    predictions.push({ label, seconds: clockToSeconds(match[2]) })
  }

  return {
    vo2max: numOf(text, 'VO2max'),
    runningLevel: numOf(text, 'Running Level'),
    thresholdPaceSeconds: secondsOf(text, 'Threshold Pace'),
    predictions,
  }
}

export const parseRecovery = (text: string) => ({
  recoveryPct: numOf(text, 'Recovery'),
  level: segment(text, 'Level'),
  fullRecoveryHours: numOf(text, 'Estimated Full Recovery'),
  raw: text.trim(),
})

export const parseProfile = (text: string) => ({
  heightCm: numOf(text, 'Height'),
  weightKg: numOf(text, 'Weight'),
  birthday: segment(text, 'Birthday')?.split('(')[0].trim() ?? null,
  age: Number(text.match(/Birthday:[^(]*\(\s*Age:\s*(\d+)/i)?.[1]) || null,
  gender: segment(text, 'Gender'),
  nickname: segment(text, 'Nickname'),
})

export interface ParsedScheduledWorkout {
  date: string
  name: string
  distanceKm: number | null
  estimatedSeconds: number | null
  loadTl: number | null
}

/** queryTrainingSchedule：一天一段，段内第一行非空文本就是课程名 */
export const parseTrainingSchedule = (text: string): ParsedScheduledWorkout[] => {
  const lines = text.split(/\r?\n/)
  const rows: ParsedScheduledWorkout[] = []
  let current: ParsedScheduledWorkout | null = null

  const push = () => {
    if (current?.name) rows.push(current)
  }

  for (const line of lines) {
    const trimmed = line.trim()
    const day = trimmed.match(/^(\d{4}-\d{2}-\d{2})$/)?.[1]
    if (day) {
      push()
      current = { date: day, name: '', distanceKm: null, estimatedSeconds: null, loadTl: null }
      continue
    }
    if (!current || !trimmed || trimmed.startsWith('===') || trimmed.startsWith('Note')) continue

    const distance = trimmed.match(/^Distance:\s*([\d.]+)\s*km/i)
    if (distance) {
      current.distanceKm = Number(distance[1])
      continue
    }
    const estimated = trimmed.match(/^Estimated Time:\s*([\d:]+)/i)
    if (estimated) {
      current.estimatedSeconds = clockToSeconds(estimated[1])
      continue
    }
    const load = trimmed.match(/^Load:\s*(\d+)/i)
    if (load) {
      current.loadTl = Number(load[1])
      continue
    }
    if (/^(Plan ID|idInPlan|Workout ID|Use Plan ID|Do not show)/i.test(trimmed)) continue
    if (!current.name) current.name = trimmed
  }

  push()
  return rows
}

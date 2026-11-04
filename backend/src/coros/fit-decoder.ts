/**
 * 极简 FIT 解码：只从高驰的活动文件里取轨迹需要的几件事。
 *
 * 不引第三方包（线上是 2C2G 弱机，产物只上传 dist，装新依赖就要动服务器），
 * 所以按 FIT 协议自己走一遍消息流：
 *   文件头 → definition/data 消息 → record(20) 的经纬度与时间 → session(18) 的汇总。
 * 字段号与缩放取自官方 FIT Profile：record 0=position_lat、1=position_long、
 * 2=altitude(scale 5, -500)、3=heart_rate、5=distance(scale 100)、78=enhanced_altitude、253=timestamp。
 */

const FIT_EPOCH_SECONDS = 631_065_600
const SEMICIRCLES_TO_DEGREES = 180 / 2 ** 31

const MSG_SESSION = 18
const MSG_RECORD = 20

const FIELD_LAT = 0
const FIELD_LON = 1
const FIELD_ALTITUDE = 2
const FIELD_HEART_RATE = 3
const FIELD_DISTANCE = 5
const FIELD_ENHANCED_ALTITUDE = 78
const FIELD_TIMESTAMP = 253
const FIELD_START_TIME = 2
const FIELD_TOTAL_ELAPSED = 7
const FIELD_TOTAL_DISTANCE = 9

/** base type 编号 → 单元素字节数（bit7 是大小端标志，读之前要清掉） */
const BASE_SIZES: Record<number, number> = {
  0: 1, 1: 1, 2: 1, 7: 1, 10: 1, 13: 1,
  3: 2, 4: 2, 11: 2, 12: 2,
  5: 4, 6: 4, 8: 4, 14: 4, 15: 4,
  9: 8, 16: 8, 17: 8,
}

interface FieldDef {
  num: number
  size: number
  base: number
}

interface MessageDef {
  global: number
  littleEndian: boolean
  fields: FieldDef[]
  devSizes: number[]
}

export interface LatLng {
  lon: number
  lat: number
}

export interface FitPoint extends LatLng {
  lon: number
  lat: number
  /** unix 秒 */
  time: number | null
  distanceMeters: number | null
  altitude: number | null
  heartRate: number | null
}

export interface FitTrack {
  points: FitPoint[]
  /** unix 秒，用于把 FIT 文件对上高驰的活动 labelId */
  startTime: number | null
  totalDistanceMeters: number | null
  totalElapsedTimeSeconds: number | null
}

class Reader {
  private cursor = 0

  constructor(private readonly bytes: Uint8Array) {}

  get offset(): number {
    return this.cursor
  }

  get done(): boolean {
    return this.cursor >= this.bytes.length
  }

  jump(to: number) {
    this.cursor = to
  }

  byte(): number {
    const value = this.bytes[this.cursor] ?? 0
    this.cursor += 1
    return value
  }

  bytesOf(length: number): Uint8Array {
    const value = this.bytes.subarray(this.cursor, this.cursor + length)
    this.cursor += length
    return value
  }

  uint16(le: boolean): number {
    const a = this.byte()
    const b = this.byte()
    return le ? a | (b << 8) : (a << 8) | b
  }

  int32(le: boolean): number {
    const a = this.byte()
    const b = this.byte()
    const c = this.byte()
    const d = this.byte()
    return le ? a | (b << 8) | (c << 16) | (d << 24) : (a << 24) | (b << 16) | (c << 8) | d
  }

  uint32(le: boolean): number {
    return this.int32(le) >>> 0
  }

  float32(le: boolean): number {
    const view = new DataView(this.bytes.buffer, this.bytes.byteOffset + this.cursor, 4)
    const value = view.getFloat32(0, le)
    this.cursor += 4
    return value
  }
}

/** FIT 用「该类型的最大值」表示无效值，uint*z 用 0 */
const isInvalidNumber = (base: number, value: number): boolean => {
  switch (base) {
    case 0:
    case 2:
    case 13:
      return value === 0xff
    case 1:
      return value === 0x7f
    case 3:
      return value === 0x7fff
    case 11:
      return value === 0
    case 4:
    case 12:
      return value === 0xffff || value === 0
    case 5:
      return value === 0x7fffffff
    case 14:
    case 15:
      return value === 0
    case 6:
      return value === 0xffffffff
    default:
      return false
  }
}

const readFieldNumber = (reader: Reader, def: FieldDef, endian: boolean): number | null => {
  const base = def.base & 0x7f
  const elementSize = BASE_SIZES[base]
  if (!elementSize || elementSize > 4) {
    reader.bytesOf(def.size)
    return null
  }

  const count = Math.max(1, Math.floor(def.size / elementSize))
  let first: number | null = null
  for (let index = 0; index < count; index += 1) {
    let value: number
    if (elementSize === 1) value = reader.byte()
    else if (elementSize === 2) value = reader.uint16(endian)
    else if (base === 8) value = reader.float32(endian)
    else value = base === 5 ? reader.int32(endian) : reader.uint32(endian)

    if (!isInvalidNumber(base, value) && first === null) first = value
  }
  return first
}

/** 压缩时间戳：32 秒一轮回累加（bit7=1，bit6-5 是本地消息号，bit4-0 是秒偏移） */
const rollTimestamp = (last: number, offset: number): number => {
  const window = 32
  const base = Math.floor(last / window) * window
  let value = base + offset
  if (value < last) value += window
  return value
}

const validCoordinate = (lon: number, lat: number): boolean =>
  Number.isFinite(lon) &&
  Number.isFinite(lat) &&
  Math.abs(lat) <= 90 &&
  Math.abs(lon) <= 180 &&
  !(lon === 0 && lat === 0)

/** 读整个 FIT，取出轨迹点与 session 汇总；结构不认识时返回空轨迹而不是抛错 */
export function decodeFitTrack(input: Uint8Array): FitTrack {
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input)
  const track: FitTrack = { points: [], startTime: null, totalDistanceMeters: null, totalElapsedTimeSeconds: null }
  if (bytes.length < 12) return track

  const header = new Reader(bytes)
  const headerSize = header.byte()
  header.byte()
  header.uint16(true)
  const dataSize = header.uint32(true)
  const isFit =
    bytes[8] === 0x2e && bytes[9] === 0x46 && bytes[10] === 0x49 && bytes[11] === 0x54
  if (!isFit || headerSize < 12) return track

  const reader = new Reader(bytes)
  reader.jump(headerSize)
  const dataEnd = Math.min(headerSize + dataSize, bytes.length)

  const definitions = new Map<number, MessageDef>()
  let lastTimestamp: number | null = null
  let sessionStart: number | null = null
  let sessionDistance: number | null = null
  let sessionElapsed: number | null = null
  let firstRecordTime: number | null = null

  while (reader.offset < dataEnd) {
    const headerByte = reader.byte()
    const compressed = (headerByte & 0x80) !== 0

    if (!compressed && (headerByte & 0x40) !== 0) {
      reader.byte()
      const littleEndian = reader.byte() === 0
      const global = reader.uint16(littleEndian)
      const fieldCount = reader.byte()
      const fields: FieldDef[] = []
      for (let index = 0; index < fieldCount; index += 1) {
        const num = reader.byte()
        const size = reader.byte()
        const base = reader.byte()
        if (size > 0) fields.push({ num, size, base })
      }
      const devSizes: number[] = []
      if ((headerByte & 0x20) !== 0) {
        const devCount = reader.byte()
        for (let index = 0; index < devCount; index += 1) {
          reader.byte()
          devSizes.push(reader.byte())
          reader.byte()
        }
      }
      definitions.set(headerByte & 0x0f, { global, littleEndian, fields, devSizes })
      continue
    }

    const local = compressed ? (headerByte >> 5) & 3 : headerByte & 0x0f
    const definition = definitions.get(local)
    if (!definition) break

    const endian = definition.littleEndian
    const values = new Map<number, number | null>()
    for (const field of definition.fields) {
      if (compressed && field.num === FIELD_TIMESTAMP) continue
      values.set(field.num, readFieldNumber(reader, field, endian))
    }
    for (const size of definition.devSizes) reader.bytesOf(size)

    let time: number | null = values.get(FIELD_TIMESTAMP) ?? null
    if (compressed && time === null) {
      time = lastTimestamp === null ? null : rollTimestamp(lastTimestamp, headerByte & 31)
    }
    if (time !== null) lastTimestamp = time

    if (definition.global === MSG_SESSION) {
      if (sessionStart === null) sessionStart = values.get(FIELD_START_TIME) ?? null
      if (sessionDistance === null) sessionDistance = values.get(FIELD_TOTAL_DISTANCE) ?? null
      if (sessionElapsed === null) sessionElapsed = values.get(FIELD_TOTAL_ELAPSED) ?? null
      continue
    }

    if (definition.global !== MSG_RECORD) continue

    const rawLat = values.get(FIELD_LAT)
    const rawLon = values.get(FIELD_LON)
    if (rawLat === undefined || rawLon === undefined || rawLat === null || rawLon === null) continue

    const lat = rawLat * SEMICIRCLES_TO_DEGREES
    const lon = rawLon * SEMICIRCLES_TO_DEGREES
    if (!validCoordinate(lon, lat)) continue

    const altitudeRaw = values.get(FIELD_ENHANCED_ALTITUDE) ?? values.get(FIELD_ALTITUDE) ?? null
    const distance = values.get(FIELD_DISTANCE)
    if (firstRecordTime === null && time !== null) firstRecordTime = time

    track.points.push({
      lon,
      lat,
      time: time === null ? null : time + FIT_EPOCH_SECONDS,
      distanceMeters: distance === null || distance === undefined ? null : distance / 100,
      altitude: altitudeRaw === null ? null : altitudeRaw / 5 - 500,
      heartRate: values.get(FIELD_HEART_RATE) ?? null,
    })
  }

  track.startTime = sessionStart !== null ? sessionStart + FIT_EPOCH_SECONDS : firstRecordTime !== null ? firstRecordTime + FIT_EPOCH_SECONDS : null
  track.totalDistanceMeters = sessionDistance !== null ? sessionDistance / 100 : null
  track.totalElapsedTimeSeconds = sessionElapsed !== null ? sessionElapsed / 1000 : null
  return track
}

const METERS_PER_DEGREE = 111_320
/** 由「1 度 ≈ 111320 米」反推的球半径，haversine 的角度要乘半径而不是乘每度米数 */
const EARTH_RADIUS_METERS = (METERS_PER_DEGREE * 180) / Math.PI

/** 局部小范围内用等距投影算垂距足够精确，也比球面公式省 */
const flatMeters = (lon: number, lat: number, originLat: number) => ({
  x: lon * METERS_PER_DEGREE * Math.cos((originLat * Math.PI) / 180),
  y: lat * METERS_PER_DEGREE,
})

export function haversineMeters(a: LatLng, b: LatLng): number {
  const toRad = Math.PI / 180
  const dLat = (b.lat - a.lat) * toRad
  const dLon = (b.lon - a.lon) * toRad
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * toRad) * Math.cos(b.lat * toRad) * Math.sin(dLon / 2) ** 2
  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(h)))
}

const perpendicularMeters = (a: LatLng, b: LatLng, p: LatLng): number => {
  const ax = flatMeters(a.lon, a.lat, a.lat)
  const bx = flatMeters(b.lon, b.lat, a.lat)
  const px = flatMeters(p.lon, p.lat, a.lat)

  const dx = bx.x - ax.x
  const dy = bx.y - ax.y
  const length = Math.hypot(dx, dy)
  if (length === 0) return Math.hypot(px.x - ax.x, px.y - ax.y)
  return Math.abs((px.x - ax.x) * dy - (px.y - ax.y) * dx) / length
}

/** Ramer–Douglas–Peucker：递归找偏离最长的点，超过容差就保留 */
const rdp = <T extends LatLng>(points: T[], tolerance: number): T[] => {
  if (points.length < 3) return points

  const keep = new Array<boolean>(points.length).fill(false)
  keep[0] = true
  keep[points.length - 1] = true
  const stack: Array<[number, number]> = [[0, points.length - 1]]

  while (stack.length) {
    const [start, end] = stack.pop()!
    let worst = 0
    let worstIndex = -1
    for (let index = start + 1; index < end; index += 1) {
      const distance = perpendicularMeters(points[start], points[end], points[index])
      if (distance > worst) {
        worst = distance
        worstIndex = index
      }
    }
    if (worst > tolerance && worstIndex > 0) {
      keep[worstIndex] = true
      stack.push([start, worstIndex], [worstIndex, end])
    }
  }

  return points.filter((_, index) => keep[index])
}

/**
 * 折线越细，app 画起来越轻、库里越省。
 * 容差从 2 米开始翻倍试，还不达标就等间隔抽点兜底（长距离徒步会密集采样）。
 */
export function simplifyTrack<T extends LatLng>(points: T[], maxPoints: number): T[] {
  if (points.length <= maxPoints) return points

  let best = points
  for (let tolerance = 2; tolerance <= 128; tolerance *= 2) {
    best = rdp(points, tolerance)
    if (best.length <= maxPoints) return best
  }

  const stride = Math.ceil(best.length / maxPoints)
  const sampled: T[] = []
  for (let index = 0; index < best.length; index += stride) sampled.push(best[index])
  if (sampled[sampled.length - 1] !== best[best.length - 1]) sampled.push(best[best.length - 1])
  return sampled
}

/** 公里标记：沿折线累加距离，每到整公里插值出一个点 */
export function trackKmMarks(points: LatLng[]): Array<{ lon: number; lat: number; km: number }> {
  const marks: Array<{ lon: number; lat: number; km: number }> = []
  if (points.length < 2) return marks

  let walked = 0
  let nextKm = 1000
  for (let index = 1; index < points.length && walked < 200_000; index += 1) {
    const previous = points[index - 1]
    const current = points[index]
    const step = haversineMeters(previous, current)
    if (step <= 0) continue

    if (walked + step >= nextKm) {
      const ratio = (nextKm - walked) / step
      marks.push({
        lon: previous.lon + (current.lon - previous.lon) * ratio,
        lat: previous.lat + (current.lat - previous.lat) * ratio,
        km: nextKm / 1000,
      })
      nextKm += 1000
    }
    walked += step
  }
  return marks
}

export function trackDistanceMeters(points: LatLng[]): number {
  let total = 0
  for (let index = 1; index < points.length; index += 1) total += haversineMeters(points[index - 1], points[index])
  return total
}

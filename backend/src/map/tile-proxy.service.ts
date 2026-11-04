import { BadRequestException, Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import {
  PLACEHOLDER_PNG,
  TIANDITU_HOSTS,
  TIANDITU_LAYERS,
  TIANDITU_MAX_ZOOM,
  TIANDITU_MIN_ZOOM,
  TILE_CACHE_MAX_BYTES,
  TILE_CACHE_TTL_MS,
  TILE_FAILURE_TTL_MS,
  TILE_RATE_LIMIT_PER_MINUTE,
  TILE_UPSTREAM_CONCURRENCY,
  TILE_UPSTREAM_TIMEOUT_MS,
} from './map.constants'

export interface TileHit {
  bytes: Buffer
  mime: string
  /** fallback = 上游没给到瓦片（Key 未配、IP 不在白名单、网络故障），返回占位图 */
  fallback: boolean
}

interface CacheEntry {
  bytes: Buffer
  mime: string
  until: number
  failed: boolean
}

/**
 * 天地图瓦片代理。
 *
 * 三件事：把 Key 留在服务端、按字节上限缓存瓦片（省配额）、
 * 上游异常时回一张透明瓦片而不是报错——地图格子上留白，轨迹折线照样画得出来。
 */
@Injectable()
export class TileProxyService {
  private readonly logger = new Logger(TileProxyService.name)
  private readonly cache = new Map<string, CacheEntry>()
  private readonly inflight = new Map<string, Promise<TileHit>>()
  private readonly buckets = new Map<string, { tokens: number; at: number }>()
  /** 上游明确说「这个图层没授权」的图层：短期内直接回透明瓦片，不再打上游 */
  private readonly deniedLayers = new Map<string, number>()
  private cachedBytes = 0
  private active = 0
  private readonly queue: Array<() => void> = []
  private warned = false

  constructor(private readonly config: ConfigService) {}

  get enabled(): boolean {
    return this.config.get<string>('TIANDITU_KEY', '').trim().length > 0
  }

  async tile(rawLayer: string, rawZoom: string, rawX: string, rawY: string, clientIp: string): Promise<TileHit> {
    const layer = TIANDITU_LAYERS[rawLayer]
    const zoom = Number(rawZoom)
    const x = Number(rawX)
    const y = Number(rawY)

    if (!layer) throw new BadRequestException(`不支持的地图图层：${rawLayer}`)
    if (!Number.isInteger(zoom) || zoom < TIANDITU_MIN_ZOOM || zoom > TIANDITU_MAX_ZOOM) {
      throw new BadRequestException('地图层级不合法')
    }
    const span = 2 ** zoom
    if (!Number.isInteger(x) || !Number.isInteger(y) || x < 0 || y < 0 || x >= span || y >= span) {
      throw new BadRequestException('瓦片坐标不合法')
    }

    if (!this.allow(clientIp)) return this.placeholder()

    const deniedUntil = this.deniedLayers.get(rawLayer)
    if (deniedUntil && deniedUntil > Date.now()) return this.placeholder()

    const key = `${rawLayer}/${zoom}/${x}/${y}`
    const hit = this.cache.get(key)
    if (hit && hit.until > Date.now()) {
      return hit.failed ? this.placeholder() : { bytes: hit.bytes, mime: hit.mime, fallback: false }
    }
    if (hit) {
      this.drop(key)
    }

    // 同一张瓦片被多个页面同时请求时只打一次上游
    const pending = this.inflight.get(key)
    if (pending) return pending

    const task = this.fetchTile(layer, zoom, x, y, key, rawLayer)
    this.inflight.set(key, task)
    try {
      return await task
    } finally {
      this.inflight.delete(key)
    }
  }

  private async fetchTile(
    spec: { path: string; layer: string },
    zoom: number,
    x: number,
    y: number,
    key: string,
    rawLayer: string,
  ) {
    const token = this.config.get<string>('TIANDITU_KEY', '').trim()
    const host = `t${(x + y) % TIANDITU_HOSTS}`
    const url =
      `https://${host}.tianditu.gov.cn/${spec.path}/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0` +
      `&LAYER=${spec.layer}&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles` +
      `&TILEMATRIX=${zoom}&TILEROW=${y}&TILECOL=${x}&tk=${token}`

    await this.acquire()
    try {
      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), TILE_UPSTREAM_TIMEOUT_MS)
      let response: Response
      try {
        response = await fetch(url, { signal: controller.signal, headers: { Accept: 'image/*' } })
      } finally {
        clearTimeout(timer)
      }

      const bytes = Buffer.from(await response.arrayBuffer())
      if (!response.ok || bytes.length < 100) {
        const reason = (bytes.subarray(0, 200).toString('utf8').match(/"msg":"([^"]{1,60})"/) ?? [])[1] ?? ''
        // 「没有 xxx/wmts 权限」= 这个 Key 没开这个图层服务，短期内所有请求都是一样的结果
        if (reason.includes('权限')) {
          this.deniedLayers.set(rawLayer, Date.now() + TILE_FAILURE_TTL_MS)
          this.logger.warn(`天地图图层 ${rawLayer} 未开通（${reason}），该图层先不请求上游`)
        }
        if (!this.warned) {
          this.warned = true
          // 天地图失败基本都是 Key 问题，回体里写着原因（IP 不在白名单 / 非法 key），抄出来省得猜
          this.logger.warn(
            `天地图瓦片获取失败（HTTP ${response.status}${reason ? `：${reason}` : ''}），底图留白但轨迹照常显示`,
          )
        }
        this.remember(key, { bytes: PLACEHOLDER_PNG, mime: 'image/png', until: Date.now() + TILE_FAILURE_TTL_MS, failed: true })
        return this.placeholder()
      }

      const entry: CacheEntry = {
        bytes,
        mime: response.headers.get('content-type') ?? 'image/png',
        until: Date.now() + TILE_CACHE_TTL_MS,
        failed: false,
      }
      this.remember(key, entry)
      return { bytes, mime: entry.mime, fallback: false }
    } catch (error) {
      this.remember(key, { bytes: PLACEHOLDER_PNG, mime: 'image/png', until: Date.now() + TILE_FAILURE_TTL_MS, failed: true })
      this.logger.warn(`天地图瓦片请求异常：${error instanceof Error ? error.message : String(error)}`)
      return this.placeholder()
    } finally {
      this.release()
    }
  }

  private placeholder(): TileHit {
    return { bytes: PLACEHOLDER_PNG, mime: 'image/png', fallback: true }
  }

  private remember(key: string, entry: CacheEntry) {
    const stale = this.cache.get(key)
    if (stale) this.cachedBytes -= stale.bytes.length

    this.cache.set(key, entry)
    this.cachedBytes += entry.bytes.length
    if (this.cachedBytes <= TILE_CACHE_MAX_BYTES) return

    // Map 保持插入顺序，从头开始丢最久没被写入的
    for (const old of this.cache.keys()) {
      if (this.cachedBytes <= TILE_CACHE_MAX_BYTES) break
      this.drop(old)
    }
  }

  private drop(key: string) {
    const entry = this.cache.get(key)
    if (!entry) return
    this.cachedBytes -= entry.bytes.length
    this.cache.delete(key)
  }

  /** 令牌桶：每 IP 每分钟限额，防止某个页面疯狂拖动把配额烧光 */
  private allow(ip: string) {
    const now = Date.now()
    const refill = TILE_RATE_LIMIT_PER_MINUTE / 60_000
    let bucket = this.buckets.get(ip)
    if (!bucket) {
      if (this.buckets.size > 4096) this.buckets.clear()
      bucket = { tokens: TILE_RATE_LIMIT_PER_MINUTE, at: now }
      this.buckets.set(ip, bucket)
    }

    bucket.tokens = Math.min(TILE_RATE_LIMIT_PER_MINUTE, bucket.tokens + (now - bucket.at) * refill)
    bucket.at = now
    if (bucket.tokens < 1) return false
    bucket.tokens -= 1
    return true
  }

  private async acquire() {
    if (this.active < TILE_UPSTREAM_CONCURRENCY) {
      this.active += 1
      return
    }
    await new Promise<void>((resolve) => this.queue.push(resolve))
    this.active += 1
  }

  private release() {
    this.active -= 1
    this.queue.shift()?.()
  }
}

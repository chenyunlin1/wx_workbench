/**
 * 天地图 WMTS 瓦片代理的固定参数。
 *
 * Key 是「服务端类型」，天地图按调用方公网 IP 做白名单校验，
 * 所以 tk 只能由后端携带（放在 .env 的 TIANDITU_KEY），
 * 前端/app 只访问我们自己的 /map/tile 路径。
 */

/** 图层代号 → 天地图 WMTS 的服务图层（layer 参数）与瓦片路径 */
export const TIANDITU_LAYERS: Record<string, { path: string; layer: string }> = {
  img: { path: 'img_w', layer: 'img' },
  img_c: { path: 'img_c_w', layer: 'img_c' },
  vec: { path: 'vec_w', layer: 'vec' },
  vec_c: { path: 'vec_c_w', layer: 'vec_c' },
  ter: { path: 'ter_w', layer: 'ter' },
  ter_c: { path: 'ter_c_w', layer: 'ter_c' },
}

/** t0~t7 是同一份内容的不同域名，分摊浏览器/服务端并发上限 */
export const TIANDITU_HOSTS = 8

export const TIANDITU_MIN_ZOOM = 1
export const TIANDITU_MAX_ZOOM = 18

/** 瓦片是静态内容：命中就长期复用，少花配额 */
export const TILE_CACHE_TTL_MS = 7 * 24 * 60 * 60_000
/** 上游失败只短期记仇，IP 白名单配好或网络恢复后立刻能重试 */
export const TILE_FAILURE_TTL_MS = 60_000
/** 弱机内存有限，按字节数淘汰而不是按张数 */
export const TILE_CACHE_MAX_BYTES = 24 * 1024 * 1024
export const TILE_UPSTREAM_TIMEOUT_MS = 8_000
/** 同时打给天地图的请求数，超过就排队，避免配额被瞬间打满 */
export const TILE_UPSTREAM_CONCURRENCY = 6
/** 单个来源 IP 一分钟最多取多少张瓦片 */
export const TILE_RATE_LIMIT_PER_MINUTE = 900

/**
 * 底图取不到时的占位瓦片：1px 全透明 PNG（RGBA 0,0,0,0）。
 * 必须是真透明——半透明红色会在影像上糊一层红底。
 */
export const PLACEHOLDER_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
  'base64',
)

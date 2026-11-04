import { Fmt } from './AppKit'

/**
 * 轨迹相关的固定色。
 * Canvas 的 strokeStyle/fillStyle 只接受字符串色值，用不了 sys.color 资源，
 * 所以折线与起终点色只能手工定（高驰 app 的轨迹是黄色，起点绿、终点红）。
 */
export class RunStyle {
  static readonly TRACK: string = '#F0A202'
  static readonly START: string = '#22C55E'
  static readonly END: string = '#EF4444'
  static readonly MARK_FILL: string = '#FFFFFF'
  static readonly MARK_EDGE: string = '#3A3A3A'
  static readonly MARK_TEXT: string = '#1F2937'
}

/** 跑步指标格式化：列表行与详情页共用同一套写法，避免两页文案对不上 */
export class RunFmt {
  /** 平均配速（秒/公里）→ 6'48" */
  static pace(seconds: number | null): string {
    if (seconds === null || seconds <= 0 || seconds >= 3600) {
      return '-'
    }
    const m = Math.floor(seconds / 60)
    const s = Math.round(seconds % 60)
    return `${m}'${s < 10 ? '0' + s : s}"`
  }

  /** 时长（秒）→ 47:39，满一小时 → 1:02:03 */
  static clock(seconds: number | null): string {
    const total = seconds === null ? 0 : Math.max(0, Math.round(seconds))
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    const ss = s < 10 ? '0' + s : '' + s
    if (h === 0) {
      return `${m}:${ss}`
    }
    return `${h}:${m < 10 ? '0' + m : m}:${ss}`
  }

  static km(value: number | null): string {
    return value === null ? '-' : value.toFixed(2)
  }

  /** 月度汇总用：秒 → 小时（保留一位） */
  static hours(seconds: number): string {
    return (seconds / 3600).toFixed(1)
  }

  /** MM-DD HH:mm：优先用高驰的 unix 秒开始时间，没有就退回活动日期 */
  static stamp(timestamp: number | null, activityDate: string): string {
    if (timestamp === null || timestamp <= 0) {
      return Fmt.shortDate(activityDate) + ' 00:00'
    }
    const d = new Date(timestamp * 1000)
    return `${Fmt.pad2(d.getMonth() + 1)}-${Fmt.pad2(d.getDate())} ${Fmt.pad2(d.getHours())}:${Fmt.pad2(d.getMinutes())}`
  }

  /** 记录标题：课程名 > 运动项目名 > 兜底 */
  static title(name: string | null, sportName: string | null): string {
    if (name !== null && name.length > 0) {
      return name
    }
    if (sportName !== null && sportName.length > 0) {
      return sportName
    }
    return '跑步'
  }
}

/**
 * Web 墨卡托瓦片换算（天地图 w 系列与 XYZ 同一套编号）。
 * 单独抽成纯函数：几何算错会让轨迹整体漂移，而这种错在编译期看不出来，只能拿样例验。
 */
export class MapGeo {
  /** 一张瓦片的边长（vp） */
  static readonly TILE: number = 256

  /** 纬度 → 世界纵坐标比例（0 是北边，1 是南边）；墨卡托在 ±85.05° 之外发散 */
  static mercV(lat: number): number {
    const clamped = Math.max(-85.05, Math.min(85.05, lat))
    const sine = Math.sin(clamped * Math.PI / 180)
    return 0.5 - Math.log((1 + sine) / (1 - sine)) / (4 * Math.PI)
  }

  static worldPx(zoom: number): number {
    return MapGeo.TILE * (2 ** zoom)
  }

  static lonToX(lon: number, zoom: number): number {
    return (lon + 180) / 360 * MapGeo.worldPx(zoom)
  }

  static latToY(lat: number, zoom: number): number {
    return MapGeo.mercV(lat) * MapGeo.worldPx(zoom)
  }

  /** bbox[minLon,minLat,maxLon,maxLat] 完整落进视口（四周留 pad）的最高整数层级 */
  static fitLevel(bbox: number[], viewW: number, viewH: number, pad: number,
    minZoom: number, maxZoom: number): number {
    if (bbox.length < 4 || viewW <= pad * 2 || viewH <= pad * 2) {
      return minZoom
    }
    const du = Math.max((bbox[2] - bbox[0]) / 360, 1e-7)
    const dv = Math.max(MapGeo.mercV(bbox[1]) - MapGeo.mercV(bbox[3]), 1e-7)
    const level = Math.floor(Math.min(Math.log2((viewW - pad * 2) / (MapGeo.TILE * du)),
      Math.log2((viewH - pad * 2) / (MapGeo.TILE * dv))))
    return Math.max(minZoom, Math.min(maxZoom, level))
  }

  /** 视口要覆盖的行列区间 [minTx, minTy, maxTx, maxTy]（未裁到世界范围） */
  static tileRange(centerX: number, centerY: number, viewW: number, viewH: number,
    zoom: number, margin: number): number[] {
    const halfW = viewW / 2 + margin * MapGeo.TILE
    const halfH = viewH / 2 + margin * MapGeo.TILE
    return [
      Math.floor((centerX - halfW) / MapGeo.TILE),
      Math.floor((centerY - halfH) / MapGeo.TILE),
      Math.floor((centerX + halfW) / MapGeo.TILE),
      Math.floor((centerY + halfH) / MapGeo.TILE)
    ]
  }
}

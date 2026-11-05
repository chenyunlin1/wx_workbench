import { pasteboard } from '@kit.BasicServicesKit'
import { toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { MapGeo, RunFmt, RunStyle } from '../../common/Running'
import { AppColor, AppFont, AppRadius, AppSpace } from '../../theme/Theme'
import { RunActivity, RunDetailResult, RunKmMark, RunSplit, RunTrackPoint } from '../../model/Models'
import { WindowUtils } from '../../utils/WindowUtils'
import { Session } from '../../store/Session'

/** 天地图瓦片是 256px，这里一格按 256vp 画，缩放层级只取整数 */
const TILE: number = 256
const MIN_ZOOM: number = 3
const MAX_ZOOM: number = 18
/** 瓦片网格在视口外多铺几列，拖动时才不会露白 */
const TILE_MARGIN: number = 2
const MAX_TILES: number = 120
/** 全览时轨迹四周留出的边距（vp），避免端点贴到屏幕边 */
const FIT_PAD: number = 52
/**
 * 瓦片 URL 的版本号。
 * ArkUI 的 Image 缓存按完整 URL 走，服务端换了瓦片内容（比如占位图从红色改成透明）
 * 之后老 URL 会一直命中旧缓存，必须换 URL 才能让手机重新拉。
 */
const TILE_VERSION: number = 2

/** 底部数据卡的高度：跟着屏高走，但不低于这个值 */
const CARD_MIN_H: number = 320
const CARD_RATIO: number = 0.56
/** 地图右侧工具条的按钮边长 */
const FLOAT_BTN: number = 34
/** 图表区高度与内边距 */
const CHART_H: number = 118
const CHART_PAD_L: number = 4
const CHART_PAD_R: number = 6
const CHART_PAD_T: number = 6
const CHART_PAD_B: number = 16
/** 配速条、图表里的绿色（高驰那套跑步绿） */
const RUN_GREEN: string = '#7CC24A'
const RUN_GREEN_DEEP: string = '#4FA92F'

class TilePos {
  tx: number = 0
  ty: number = 0

  constructor(tx: number, ty: number) {
    this.tx = tx
    this.ty = ty
  }
}

/** 指标格：数值 + 单位 + 名称 */
class RunMetric {
  label: string = ''
  value: string = ''
  unit: string = ''

  constructor(label: string, value: string, unit: string = '') {
    this.label = label
    this.value = value
    this.unit = unit
  }
}

/**
 * 跑步详情页：上方是轨迹地图，下方是一整屏可滚的数据卡。
 *
 * 版式对齐高驰 app：大号距离 + 快慢渐变条 + 九宫格指标 + 配速分段条 +
 * 心率曲线 + 海拔曲线 + 分享按钮。
 *
 * 瓦片走后端 /map/tile 代理（Key 在服务端），轨迹点已经抽稀到 700 个以内，
 * 所以手势只做「整幅挪动 + 层级切换」，不做连续小数缩放——那需要重画整片瓦片。
 */
@ComponentV2
export struct RunDetailPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local titleText: string = '跑步记录';
  @Local subtitleText: string = '';
  @Local sportText: string = '跑步';
  @Local activity: RunActivity | null = null;
  @Local stats: RunMetric[] = [];
  @Local splits: RunSplit[] = [];
  @Local distanceText: string = '-';
  /** 快慢渐变条上标记的位置（0~100） */
  @Local paceMarker: number = 50;
  @Local points: RunTrackPoint[] = [];
  @Local marks: RunKmMark[] = [];
  @Local bbox: number[] = [];
  @Local noteText: string = '';
  @Local loading: boolean = true;
  @Local satellite: boolean = true;
  @Local showMarks: boolean = true;
  @Local tiles: TilePos[] = [];
  @Local zoom: number = 12;
  @Local centerX: number = 0;
  @Local centerY: number = 0;
  @Local dragX: number = 0;
  @Local dragY: number = 0;
  @Local pinch: number = 1;
  @Local viewW: number = 0;
  @Local viewH: number = 0;
  @Local panelH: number = CARD_MIN_H;
  private fitted: boolean = false;

  aboutToAppear(): void {
    const labelId = AppStorage.get<string>('runDetailLabelId')
    if (labelId === undefined || labelId.length === 0) {
      this.loading = false
      this.noteText = '没有要查看的记录'
      return
    }
    Api.runningActivityDetail(labelId).then((detail: RunDetailResult) => {
      const activity: RunActivity = detail.activity
      this.activity = activity
      this.titleText = RunFmt.title(activity.name, activity.sportName)
      this.subtitleText = RunFmt.stamp(activity.startTimestamp, activity.activityDate)
      this.sportText = activity.sportName === null || activity.sportName.length === 0 ? '跑步' : activity.sportName
      this.distanceText = RunFmt.km(activity.distanceKm)
      this.splits = detail.splits === undefined ? [] : detail.splits
      this.stats = this.statsOf(activity)
      this.paceMarker = this.markerOf()

      const track = detail.track
      if (track === null || track.points.length < 2) {
        this.noteText = '这条记录没有 GPS 轨迹（室内运动或高驰未回传活动文件）'
        // 没轨迹就退回起点坐标，至少地图上是用户跑过的那个位置
        if (activity.startLat !== null && activity.startLon !== null) {
          this.centerOn(activity.startLon, activity.startLat, 14)
        }
      } else {
        this.points = track.points
        this.marks = track.kmMarks
        this.bbox = track.bbox === null || track.bbox.length < 4
          ? this.bboxOf(track.points)
          : track.bbox
      }
    }).catch((err: Object) => {
      this.noteText = err instanceof Error ? err.message : '记录详情加载失败'
      toast(this.noteText)
    }).finally(() => {
      this.loading = false
      this.tryFit()
    })
  }

  /** 九宫格：用时 / 平均配速 / 平均心率 · 步频 / 步幅 / 爬升 · 最快1公里 / 步数 / 大卡 */
  private statsOf(activity: RunActivity): RunMetric[] {
    return [
      new RunMetric('用时', RunFmt.clock(activity.durationSeconds)),
      new RunMetric('平均配速', RunFmt.pace(activity.paceSeconds), '/km'),
      new RunMetric('平均心率', activity.avgHr === null ? '-' : activity.avgHr.toString(), 'bpm'),
      new RunMetric('平均步频', activity.avgCadence === null ? '-' : activity.avgCadence.toString(), 'spm'),
      new RunMetric('平均步幅', activity.avgStrideCm === null ? '-' : activity.avgStrideCm.toString(), 'cm'),
      new RunMetric('累计爬升', activity.elevationGain === null ? '-' : activity.elevationGain.toString(), 'm'),
      new RunMetric('最快 1 公里', RunFmt.pace(this.bestKmSeconds() ?? activity.bestKmSeconds)),
      new RunMetric('总步数', activity.steps === null ? '-' : activity.steps.toString()),
      new RunMetric('大卡', activity.calories === null ? '-' : activity.calories.toString(), 'kcal')
    ]
  }

  /* ---------------- 分段数据 ---------------- */

  /** 满一公里的段；最后那一小段单独算「不足一公里」 */
  private fullKmSplits(): RunSplit[] {
    return this.splits.filter((split: RunSplit) => split.distanceMeters >= 900)
  }

  private remainderSplit(): RunSplit | null {
    const rest = this.splits.filter((split: RunSplit) => split.distanceMeters < 900)
    return rest.length > 0 ? rest[rest.length - 1] : null
  }

  /** 最慢配速是 100%，平均配速落在哪 */
  private markerOf(): number {
    const paces = this.fullKmSplits().map((split: RunSplit) => split.paceSeconds).filter((p: number) => p > 0)
    if (paces.length === 0) {
      return 50
    }
    const min = Math.min(...paces)
    const max = Math.max(...paces)
    if (max <= min) {
      return 50
    }
    const avg = paces.reduce((sum: number, value: number) => sum + value, 0) / paces.length
    return Math.max(0, Math.min(100, (avg - min) / (max - min) * 100))
  }

  /** 配速条的长度：越慢的公里条越长 */
  private paceBarPct(split: RunSplit): number {
    const paces = this.fullKmSplits().map((item: RunSplit) => item.paceSeconds).filter((p: number) => p > 0)
    if (paces.length === 0) {
      return 100
    }
    const max = Math.max(...paces)
    if (max <= 0) {
      return 100
    }
    return Math.max(28, Math.min(100, split.paceSeconds / max * 100))
  }

  /** 跑到第 n 公里时的累计用时（秒） */
  private cumulativeAtKm(km: number): number | null {
    const list = this.fullKmSplits()
    if (km <= 0 || km > list.length) {
      return null
    }
    return list[km - 1].cumulativeSeconds
  }

  /** 心率曲线：每个公里一个平均心率，横轴是分钟 */
  private hrSeries(): number[][] {
    const points: number[][] = []
    let seeded = false
    for (const split of this.splits) {
      if (split.avgHr === null || split.avgHr <= 0) {
        continue
      }
      const x = split.cumulativeSeconds / 60
      if (!seeded) {
        points.push([0, split.avgHr])
        seeded = true
      }
      points.push([x, split.avgHr])
    }
    return points
  }

  /** 海拔曲线：按公里累加爬升，横轴是分钟 */
  private elevationSeries(): number[][] {
    const points: number[][] = [[0, 0]]
    let climbed = 0
    for (const split of this.splits) {
      climbed += split.elevationGain === null ? 0 : split.elevationGain
      points.push([split.cumulativeSeconds / 60, climbed])
    }
    return points.length > 1 ? points : []
  }

  private totalMinutes(): number {
    const last = this.splits.length > 0 ? this.splits[this.splits.length - 1] : null
    const seconds = last === null ? 0 : last.cumulativeSeconds
    return Math.max(1, seconds / 60)
  }

  /**
   * 图表宽度：整屏宽 − 卡片左右外边距 24 − 内容内边距 32 − 纵轴刻度列 34。
   * 直接从屏宽推出来而不是量布局，才能保证 Path 与 Polyline 用同一套坐标。
   */
  private chartWidth(): number {
    return Math.max(120, this.viewW - 90)
  }

  /** 曲线点 → 画布坐标 */
  private chartPoints(series: number[][], minV: number, maxV: number, xMax: number,
    width: number, height: number): number[][] {    if (width <= 0 || height <= 0 || series.length === 0) {
      return []
    }
    const innerW = width - CHART_PAD_L - CHART_PAD_R
    const innerH = height - CHART_PAD_T - CHART_PAD_B
    const span = Math.max(1, maxV - minV)
    const points: number[][] = []
    for (const item of series) {
      const x = CHART_PAD_L + Math.max(0, Math.min(1, item[0] / xMax)) * innerW
      const y = CHART_PAD_T + (1 - Math.max(0, Math.min(1, (item[1] - minV) / span))) * innerH
      points.push([x, y])
    }
    return points
  }

  /** 折线下方的填充路径 */
  /**
   * 面积图的填充多边形：曲线 + 两端落到底线。
   * 不用 Path.commands —— 宽度变化时 Path 会留下上一帧的残影（截图里那条黑线）。
   */
  private areaPoints(series: number[][], minV: number, maxV: number, xMax: number,
    width: number, height: number): number[][] {
    const points = this.chartPoints(series, minV, maxV, xMax, width, height)
    if (points.length === 0) {
      return []
    }
    const bottom = height - CHART_PAD_B
    const polygon: number[][] = [[points[0][0], bottom]]
    for (const point of points) {
      polygon.push(point)
    }
    polygon.push([points[points.length - 1][0], bottom])
    return polygon
  }

  private hrRange(): number[] {
    const values = this.hrSeries().map((item: number[]) => item[1])
    if (values.length === 0) {
      return [60, 160]
    }
    const min = Math.min(...values)
    const max = Math.max(...values)
    return [Math.max(30, min - 12), max + 12]
  }

  private elevationRange(): number[] {
    const values = this.elevationSeries().map((item: number[]) => item[1])
    if (values.length === 0) {
      return [0, 10]
    }
    const max = Math.max(...values)
    return [0, Math.max(10, max + 5)]
  }

  /** 纵轴刻度：最高、次高、次低、最低 */
  private axisLabels(range: number[]): string[] {
    const max = range[1]
    const min = range[0]
    const step = (max - min) / 3
    return [
      max.toFixed(0),
      (max - step).toFixed(0),
      (min + step).toFixed(0),
      min.toFixed(0)
    ]
  }

  /** 分享：把这次运动的摘要复制到剪贴板 */
  private shareSummary(): void {
    const activity = this.activity
    const lines: string[] = []
    lines.push(`${this.sportText} ${this.distanceText} 公里`)
    if (activity !== null) {
      lines.push(`用时 ${RunFmt.clock(activity.durationSeconds)}`)
      lines.push(`平均配速 ${RunFmt.pace(activity.paceSeconds)}`)
      lines.push(`平均心率 ${activity.avgHr === null ? '-' : activity.avgHr.toString()} bpm`)
      lines.push(`累计爬升 ${activity.elevationGain === null ? '-' : activity.elevationGain.toString()} m`)
    }
    lines.push(this.subtitleText)
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, lines.join('\n'))
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      toast('运动摘要已复制到剪贴板')
    }).catch(() => {
      toast('复制失败')
    })
  }

  /** 服务端没给 bbox 时自己算一份，全览才有依据 */
  private bboxOf(points: RunTrackPoint[]): number[] {
    if (points.length === 0) {
      return []
    }
    let minLon: number = Infinity
    let minLat: number = Infinity
    let maxLon: number = -Infinity
    let maxLat: number = -Infinity
    for (const point of points) {
      minLon = Math.min(minLon, point.lon)
      maxLon = Math.max(maxLon, point.lon)
      minLat = Math.min(minLat, point.lat)
      maxLat = Math.max(maxLat, point.lat)
    }
    return [minLon, minLat, maxLon, maxLat]
  }

  /* ---------------- 瓦片与坐标换算 ---------------- */

  private tileUrl(layer: string, tx: number, ty: number): string {
    return `${Session.serverUrl}/api/map/tile/${layer}/${this.zoom}/${tx}/${ty}?v=${TILE_VERSION}`
  }

  private baseLayer(): string {
    return this.satellite ? 'img' : 'vec'
  }

  private labelLayer(): string {
    return this.satellite ? 'img_c' : 'vec_c'
  }

  private screenX(lon: number): number {
    return MapGeo.lonToX(lon, this.zoom) - this.shiftX()
  }

  private screenY(lat: number): number {
    return MapGeo.latToY(lat, this.zoom) - this.shiftY()
  }

  /** 视口左上角落在世界像素上的哪个位置；瓦片排布与轨迹绘制共用 */
  private shiftX(): number {
    return this.centerX - this.viewW / 2 - this.dragX
  }

  private shiftY(): number {
    return this.centerY - this.viewH / 2 - this.dragY
  }

  private rebuildTiles(): void {
    if (this.viewW <= 0 || this.viewH <= 0) {
      return
    }
    const cols = 2 ** this.zoom
    const range = MapGeo.tileRange(this.centerX, this.centerY, this.viewW, this.viewH, this.zoom, TILE_MARGIN)
    const list: TilePos[] = []
    for (let ty = range[1]; ty <= range[3]; ty += 1) {
      for (let tx = range[0]; tx <= range[2]; tx += 1) {
        // 超出世界范围的行列没有瓦片，直接跳过
        if (tx < 0 || ty < 0 || tx >= cols || ty >= cols) {
          continue
        }
        if (list.length >= MAX_TILES) {
          break
        }
        list.push(new TilePos(tx, ty))
      }
    }
    this.tiles = list
  }

  private clampCenter(): void {
    const span = MapGeo.worldPx(this.zoom)
    this.centerX = Math.max(0, Math.min(span, this.centerX))
    this.centerY = Math.max(0, Math.min(span, this.centerY))
  }

  /** 卡片上方的可见高度：轨迹全览只在这一块里铺开 */
  private visibleH(): number {
    return Math.max(this.viewH - this.panelH, 160)
  }

  /** 把轨迹缩放到刚好铺满卡片上方的地图区 */
  private fitTrack(): void {
    if (this.bbox.length < 4) {
      return
    }
    const height = this.visibleH()
    this.zoom = MapGeo.fitLevel(this.bbox, this.viewW, height, FIT_PAD, MIN_ZOOM, MAX_ZOOM)
    this.centerX = MapGeo.lonToX((this.bbox[0] + this.bbox[2]) / 2, this.zoom)
    // 视口中心要下移半张卡片，轨迹才落在卡片上方而不是被卡片压住
    this.centerY = (MapGeo.mercV(this.bbox[3]) + MapGeo.mercV(this.bbox[1])) / 2 * MapGeo.worldPx(this.zoom)
      + this.panelH / 2
    this.dragX = 0
    this.dragY = 0
    this.pinch = 1
    this.rebuildTiles()
  }

  /** 把视口中心放到指定经纬度的固定层级（没有轨迹时退回起点定位） */
  private centerOn(lon: number, lat: number, level: number): void {
    this.zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, level))
    this.centerX = MapGeo.lonToX(lon, this.zoom)
    this.centerY = MapGeo.latToY(lat, this.zoom) + this.panelH / 2
    this.dragX = 0
    this.dragY = 0
    this.pinch = 1
    this.rebuildTiles()
  }

  private tryFit(): void {
    if (this.fitted || this.viewW <= 0 || this.bbox.length < 4) {
      return
    }
    this.fitted = true
    this.fitTrack()
  }

  private zoomBy(delta: number): void {
    const next = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, this.zoom + delta))
    if (next === this.zoom) {
      return
    }
    const factor = 2 ** (next - this.zoom)
    this.centerX *= factor
    this.centerY *= factor
    this.zoom = next
    this.dragX = 0
    this.dragY = 0
    this.pinch = 1
    this.clampCenter()
    this.rebuildTiles()
  }

  private commitDrag(): void {
    this.centerX -= this.dragX
    this.centerY -= this.dragY
    this.dragX = 0
    this.dragY = 0
    this.clampCenter()
    this.rebuildTiles()
  }

  /* ---------------- 轨迹绘制 ---------------- */

  /**
   * 轨迹顶点的屏幕坐标。
   * 早先用 Canvas 画线，但 Canvas 在 onReady / onAreaChange 时会被清空，
   * 轨迹画上去就会被抹掉；改成声明式 Polyline 后随状态自动重绘。
   */
  private trackPolyline(): number[][] {
    const vertices: number[][] = []
    for (const point of this.points) {
      vertices.push([this.screenX(point.lon), this.screenY(point.lat)])
    }
    return vertices
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 底图铺满整屏，卡片浮在下面
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.tiles, (tile: TilePos) => {
          Image(this.tileUrl(this.baseLayer(), tile.tx, tile.ty))
            .width(TILE)
            .height(TILE)
            .position({ x: tile.tx * TILE - this.shiftX(), y: tile.ty * TILE - this.shiftY() })
        }, (tile: TilePos) => this.zoom + '/' + tile.tx + '/' + tile.ty)

        ForEach(this.tiles, (tile: TilePos) => {
          Image(this.tileUrl(this.labelLayer(), tile.tx, tile.ty))
            .width(TILE)
            .height(TILE)
            .position({ x: tile.tx * TILE - this.shiftX(), y: tile.ty * TILE - this.shiftY() })
        }, (tile: TilePos) => 'c' + this.zoom + '/' + tile.tx + '/' + tile.ty)

        // 轨迹层：声明式形状，随状态变化自动重绘（Canvas 会被清空，轨迹会消失）
        if (this.points.length >= 2) {
          // 先描一条深色底线，影像底图上黄色线才不会糊掉
          Polyline({ width: this.viewW, height: this.viewH })
            .points(this.trackPolyline())
            .fill('#00000000')
            .stroke('#00000073')
            .strokeWidth(8)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
            .position({ x: 0, y: 0 })
            .hitTestBehavior(HitTestMode.None)

          Polyline({ width: this.viewW, height: this.viewH })
            .points(this.trackPolyline())
            .fill('#00000000')
            .stroke(RunStyle.TRACK)
            .strokeWidth(4)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
            .position({ x: 0, y: 0 })
            .hitTestBehavior(HitTestMode.None)

          if (this.showMarks) {
            ForEach(this.marks, (mark: RunKmMark) => {
              Stack() {
                Circle({ width: 16, height: 16 })
                  .fill(RunStyle.MARK_FILL)
                Text(mark.km.toString())
                  .fontSize(10)
                  .fontColor(RunStyle.MARK_TEXT)
              }
              .width(16)
              .height(16)
              .position({ x: this.screenX(mark.lon) - 8, y: this.screenY(mark.lat) - 8 })
              .hitTestBehavior(HitTestMode.None)
            }, (mark: RunKmMark) => mark.km.toString())
          }

          Circle({ width: 14, height: 14 })
            .fill(RunStyle.START)
            .stroke('#FFFFFF')
            .strokeWidth(2)
            .position({
              x: this.screenX(this.points[0].lon) - 7,
              y: this.screenY(this.points[0].lat) - 7
            })
            .hitTestBehavior(HitTestMode.None)

          Circle({ width: 14, height: 14 })
            .fill(RunStyle.END)
            .stroke('#FFFFFF')
            .strokeWidth(2)
            .position({
              x: this.screenX(this.points[this.points.length - 1].lon) - 7,
              y: this.screenY(this.points[this.points.length - 1].lat) - 7
            })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
      .height('100%')
      .scale({ x: this.pinch, y: this.pinch })
      .gesture(
        PanGesture({ fingers: 1, distance: 4 })
          .onActionUpdate((event: GestureEvent) => {
            this.dragX = event.offsetX
            this.dragY = event.offsetY
          })
          .onActionEnd(() => {
            this.commitDrag()
          })
      )
      .priorityGesture(
        PinchGesture({ fingers: 2 })
          .onActionUpdate((event: GestureEvent) => {
            this.pinch = event.scale
          })
          .onActionEnd((event: GestureEvent) => {
            const step = Math.round(Math.log2(event.scale))
            this.pinch = 1
            if (step !== 0) {
              this.zoomBy(step)
            }
          })
      )
      .onSizeChange((_oldValue: SizeOptions, newValue: SizeOptions) => {
        if (typeof newValue.width !== 'number' || typeof newValue.height !== 'number') {
          return
        }
        this.viewW = newValue.width
        this.viewH = newValue.height
        this.panelH = Math.max(CARD_MIN_H, Math.round(newValue.height * CARD_RATIO))
        this.rebuildTiles()
        this.tryFit()
      })

      // 顶部：返回按钮在左，中间是这条记录的时间
      Row() {
        this.backButton()
        Blank()
        Text(this.subtitleText)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor('#4D000000')
        Blank()
        this.moreButton()
      }
      .width('100%')
      .padding({ top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm, left: AppSpace.Md, right: AppSpace.Md })
      .alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)

      // 右侧工具条
      Row() {
        Blank()
        Column({ space: 6 }) {
          this.mapIconButton(this.satellite ? $r('sys.symbol.satellite_map') : $r('sys.symbol.map'), (): void => {
            this.satellite = !this.satellite
          })
          this.mapIconButton($r('sys.symbol.arrow_up_left_and_arrow_down_right'), (): void => {
            this.fitTrack()
          })
          this.mapIconButton(this.showMarks ? $r('sys.symbol.flag_fill') : $r('sys.symbol.flag'), (): void => {
            this.showMarks = !this.showMarks
          })
          this.mapIconButton($r('sys.symbol.plus'), (): void => {
            this.zoomBy(1)
          })
          this.mapIconButton($r('sys.symbol.minus'), (): void => {
            this.zoomBy(-1)
          })
        }
        .padding({ top: 6, bottom: 6, left: 4, right: 4 })
        .borderRadius(20)
        .backgroundColor('#F2FFFFFF')
        .shadow({ radius: 10, color: '#33000000', offsetY: 2 })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: WindowUtils.getStatusBarHeightVp() + AppSpace.Xl, right: AppSpace.Md })
      .hitTestBehavior(HitTestMode.Transparent)

      if (!this.loading && this.points.length < 2) {
        Column() {
          Text(this.noteText.length > 0 ? this.noteText : '这条记录没有可显示的轨迹')
            .fontSize(AppFont.Body)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: this.panelH })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 底部数据卡：容器只占卡片本身的范围，默认命中测试会挡住下面的地图，
      // 卡片里的 Scroll 才能拿到纵向滑动（整屏 Transparent 容器会让地图平移抢走手势）
      Column() {
        this.dataCard()
      }
      .width('100%')
      .height(this.panelH)
      .padding({ left: 12, right: 12 })
      .position({ x: 0, y: this.viewH - this.panelH - 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  backButton() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(26)
        .fontColor(['#FFFFFF'])
        .width(28)
        .height(28)
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor('#4D000000')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.nav.pop()
    })
  }

  @Builder
  moreButton() {
    Row() {
      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize(20)
        .fontColor(['#FFFFFF'])
        .width(22)
        .height(22)
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor('#4D000000')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.shareSummary()
    })
  }

  @Builder
  mapIconButton(symbol: Resource, action: () => void) {
    Row() {
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor(['#1F2937'])
        .width(20)
        .height(20)
    }
    .width(FLOAT_BTN)
    .height(FLOAT_BTN)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      action()
    })
  }

  @Builder
  dataCard() {
    Column() {
      Scroll() {
        Column({ space: AppSpace.Md }) {
          this.cardHeader()
          this.distanceBlock()
          this.statGrid()
          this.paceSection()
          this.heartSection()
          this.elevationSection()
          this.shareButton()
        }
        .width('100%')
        .padding({ left: AppSpace.Md, right: AppSpace.Md, top: AppSpace.Md, bottom: AppSpace.Xl })
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height(this.panelH)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(AppRadius.Lg)
    .clip(true)
    .shadow({ radius: 18, color: '#26000000', offsetY: 2 })
  }

  /** 卡片顶部：项目标签 + 标题 + 时间（标题与时间同一行，放在最上面） */
  @Builder
  cardHeader() {
    Row({ space: AppSpace.Xs }) {
      Text(this.sportText)
        .fontSize(11)
        .fontColor('#FFFFFF')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(6)
        .backgroundColor(RUN_GREEN_DEEP)
      Text(this.titleText)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.subtitleText)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /** 大号距离 + 快慢渐变条 */
  @Builder
  distanceBlock() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(this.distanceText)
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
        Text('公里')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ bottom: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .borderRadius(2)
          .linearGradient({
            angle: 0,
            colors: [['#5B8FF9', 0.0], ['#5AD8A6', 0.45], ['#FACC15', 0.72], ['#F56C6C', 1.0]]
          })
        Circle({ width: 8, height: 8 })
          .fill('#FFFFFF')
          .stroke('#3A3A3A')
          .strokeWidth(1)
          .position({ x: `${this.paceMarker}%` })
          .margin({ left: -4 })
      }
      .width('100%')
      .height(10)

      Row() {
        Text('慢')
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        Text('快')
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 九宫格指标 */
  @Builder
  statGrid() {
    GridRow({ columns: 3, gutter: 8 }) {
      ForEach(this.stats, (item: RunMetric) => {
        GridCol({ span: 1 }) {
          Column({ space: 3 }) {
            Row({ space: 3 }) {
              Text(item.value)
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (item.unit.length > 0) {
                Text(item.unit)
                  .fontSize(10)
                  .fontColor($r('sys.color.font_secondary'))
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)

            Text(item.label)
              .fontSize(10)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: AppSpace.Xs, bottom: AppSpace.Xs })
          .borderRadius(AppRadius.Sm)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .alignItems(HorizontalAlign.Center)
        }
      }, (item: RunMetric) => item.label)
    }
    .width('100%')
  }

  /** 配速：每个公里一条，条长表示这一公里有多慢 */
  @Builder
  paceSection() {
    Column({ space: 8 }) {
      Row() {
        Text('配速')
          .fontSize(AppFont.Title)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('平均: ' + RunFmt.pace(this.avgPaceSeconds()))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
        Text('　公里最快: ' + RunFmt.pace(this.bestKmSeconds()))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')

      if (this.fullKmSplits().length === 0) {
        Text('分段数据还没有同步，下拉刷新后再看')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      } else {
        Row() {
          Text('公里')
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .width(24)
          Text('配速/公里')
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
          Text('累计用时')
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .width(66)
            .textAlign(TextAlign.End)
        }
        .width('100%')

        ForEach(this.fullKmSplits(), (split: RunSplit) => {
          this.paceRow(split)
        }, (split: RunSplit) => split.index.toString())

        if (this.fiveKmNote().length > 0) {
          Text(this.fiveKmNote())
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 2 })
        }

        if (this.remainderSplit() !== null) {
          Text('最后不足一公里用时 ' + RunFmt.clock(this.remainderSplit()!.seconds))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm })
    .borderRadius(AppRadius.Md)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  @Builder
  paceRow(split: RunSplit) {
    Row({ space: 8 }) {
      Text(split.index.toString())
        .fontSize(12)
        .fontColor($r('sys.color.font_primary'))
        .width(24)

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(18)
          .borderRadius(9)
          .backgroundColor('#1A000000')
        Row()
          .width(`${this.paceBarPct(split)}%`)
          .height(18)
          .borderRadius(9)
          .backgroundColor(RUN_GREEN)
        Text(RunFmt.pace(split.paceSeconds))
          .fontSize(11)
          .fontColor('#1F2937')
          .margin({ left: 8 })
          .align(Alignment.Center)
      }
      .layoutWeight(1)
      .height(18)

      Text(RunFmt.clock(split.cumulativeSeconds))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width(66)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /** 心率：平均值 + 曲线 */
  @Builder
  heartSection() {
    Column({ space: 6 }) {
      Row() {
        Text('心率')
          .fontSize(AppFont.Title)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('平均: ' + this.avgHrText() + '　最大: ' + this.maxHrText())
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
        Text('　次/分钟')
          .fontSize(12)
          .fontColor('#E5484D')
      }
      .width('100%')

      if (this.hrSeries().length === 0) {
        Text('这次运动没有心率分段数据')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.axisLabels(this.hrRange()), (label: string, index: number) => {
            Text(label)
              .fontSize(9)
              .fontColor($r('sys.color.font_tertiary'))
              .width(28)
              .textAlign(TextAlign.End)
              .position({ x: 0, y: this.axisY(index) - 6 })
          }, (label: string) => label)

          Polyline({ width: this.chartWidth(), height: CHART_H })
            .points(this.chartPoints(this.hrSeries(), this.hrRange()[0], this.hrRange()[1],
              this.totalMinutes(), this.chartWidth(), CHART_H))
            .fill('#00000000')
            .stroke('#E5484D')
            .strokeWidth(2)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
            .position({ x: 34, y: 0 })
            .hitTestBehavior(HitTestMode.None)

          ForEach(this.xAxisLabels(), (label: string, index: number) => {
            Text(label)
              .fontSize(9)
              .fontColor($r('sys.color.font_tertiary'))
              .width(28)
              .textAlign(TextAlign.Center)
              .position({ x: 34 + this.axisX(index) - 14, y: CHART_H - CHART_PAD_B + 2 })
          }, (label: string) => label)

          Text('分钟')
            .fontSize(9)
            .fontColor('#E5484D')
            .position({ x: this.chartWidth() + 20, y: CHART_H - CHART_PAD_B + 2 })
        }
        .width('100%')
        .height(CHART_H)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm })
    .borderRadius(AppRadius.Md)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  /** 海拔：累计爬升 + 面积图 */
  @Builder
  elevationSection() {
    Column({ space: 6 }) {
      Row() {
        Text('海拔')
          .fontSize(AppFont.Title)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text('累计爬升: ' + this.climbText())
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
        Text('　米')
          .fontSize(12)
          .fontColor(RUN_GREEN_DEEP)
      }
      .width('100%')

      if (this.elevationSeries().length === 0) {
        Text('这次运动没有海拔分段数据')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.axisLabels(this.elevationRange()), (label: string, index: number) => {
            Text(label)
              .fontSize(9)
              .fontColor($r('sys.color.font_tertiary'))
              .width(28)
              .textAlign(TextAlign.End)
              .position({ x: 0, y: this.axisY(index) - 6 })
          }, (label: string) => label)

          Polyline({ width: this.chartWidth(), height: CHART_H })
            .points(this.areaPoints(this.elevationSeries(), this.elevationRange()[0], this.elevationRange()[1],
              this.totalMinutes(), this.chartWidth(), CHART_H))
            .fill('#33A0E070')
            .stroke('#00000000')
            .strokeWidth(0)
            .position({ x: 34, y: 0 })
            .hitTestBehavior(HitTestMode.None)

          Polyline({ width: this.chartWidth(), height: CHART_H })
            .points(this.chartPoints(this.elevationSeries(), this.elevationRange()[0], this.elevationRange()[1],
              this.totalMinutes(), this.chartWidth(), CHART_H))
            .fill('#00000000')
            .stroke(RUN_GREEN_DEEP)
            .strokeWidth(2)
            .strokeLineCap(LineCapStyle.Round)
            .strokeLineJoin(LineJoinStyle.Round)
            .position({ x: 34, y: 0 })
            .hitTestBehavior(HitTestMode.None)

          ForEach(this.xAxisLabels(), (label: string, index: number) => {
            Text(label)
              .fontSize(9)
              .fontColor($r('sys.color.font_tertiary'))
              .width(28)
              .textAlign(TextAlign.Center)
              .position({ x: 34 + this.axisX(index) - 14, y: CHART_H - CHART_PAD_B + 2 })
          }, (label: string) => label)

          Text('分钟')
            .fontSize(9)
            .fontColor(RUN_GREEN_DEEP)
            .position({ x: this.chartWidth() + 20, y: CHART_H - CHART_PAD_B + 2 })
        }
        .width('100%')
        .height(CHART_H)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm })
    .borderRadius(AppRadius.Md)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  @Builder
  shareButton() {
    Row() {
      Text('分享运动记录')
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
    }
    .width('100%')
    .height(46)
    .borderRadius(23)
    .backgroundColor(RUN_GREEN_DEEP)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.shareSummary()
    })
  }

  /* ---------------- 汇总取值 ---------------- */

  private avgPaceSeconds(): number | null {
    const paces = this.fullKmSplits().map((split: RunSplit) => split.paceSeconds).filter((p: number) => p > 0)
    if (paces.length === 0) {
      return null
    }
    return Math.round(paces.reduce((sum: number, value: number) => sum + value, 0) / paces.length)
  }

  private bestKmSeconds(): number | null {
    const paces = this.fullKmSplits().map((split: RunSplit) => split.paceSeconds).filter((p: number) => p > 0)
    if (paces.length === 0) {
      return null
    }
    return Math.min(...paces)
  }

  private avgHrText(): string {
    const values = this.hrSeries().map((item: number[]) => item[1])
    if (values.length === 0) {
      return '-'
    }
    return Math.round(values.reduce((sum: number, value: number) => sum + value, 0) / values.length).toString()
  }

  private maxHrText(): string {
    const values = this.hrSeries().map((item: number[]) => item[1])
    if (values.length === 0) {
      return '-'
    }
    return Math.max(...values).toString()
  }

  private climbText(): string {
    const values = this.elevationSeries().map((item: number[]) => item[1])
    if (values.length === 0) {
      return '0.00'
    }
    return Math.max(...values).toFixed(2)
  }

  /** 「5公里累计用时 / 近5公里用时」这两行提示 */
  private fiveKmNote(): string {
    const list = this.fullKmSplits()
    if (list.length < 6) {
      return ''
    }
    const five = this.cumulativeAtKm(5)
    if (five === null) {
      return ''
    }
    let note = '5公里累计用时 ' + RunFmt.clock(five)
    const before = this.cumulativeAtKm(list.length - 5)
    if (before !== null) {
      const last = list[list.length - 1].cumulativeSeconds
      note += '　近5公里用时 ' + RunFmt.clock(last - before)
    }
    return note
  }

  /** 横轴刻度：0、10、20… 分钟 */
  private xAxisLabels(): string[] {
    const total = Math.ceil(this.totalMinutes())
    const labels: string[] = []
    for (let minute = 0; minute <= total; minute += 10) {
      labels.push(minute.toString())
    }
    if (labels.length === 0 || labels[labels.length - 1] !== total.toString()) {
      labels.push(total.toString())
    }
    return labels
  }

  private axisX(index: number): number {
    const labels = this.xAxisLabels()
    if (labels.length === 0) {
      return 0
    }
    const total = Math.ceil(this.totalMinutes())
    const value = Number(labels[index])
    return value / Math.max(1, total) * (this.chartWidth() - CHART_PAD_L - CHART_PAD_R)
  }

  /** 纵轴刻度的 y 坐标 */
  private axisY(index: number): number {
    const innerH = CHART_H - CHART_PAD_T - CHART_PAD_B
    const steps = 3
    return CHART_PAD_T + (index / steps) * innerH
  }
}

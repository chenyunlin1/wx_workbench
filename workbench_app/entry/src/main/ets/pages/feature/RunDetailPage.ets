import { toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { MapGeo, RunFmt, RunStyle } from '../../common/Running'
import { AppColor, AppFont, AppRadius, AppSpace } from '../../theme/Theme'
import { RunActivity, RunDetailResult, RunKmMark, RunTrackPoint } from '../../model/Models'
import { PAGE_PAD_H, PageHeader } from '../../components/Ui'
import { Session } from '../../store/Session'

/** 天地图瓦片是 256px，这里一格按 256vp 画，缩放层级只取整数 */
const TILE: number = 256
const MIN_ZOOM: number = 3
const MAX_ZOOM: number = 18
/** 瓦片网格在视口外多铺几列，拖动时才不会露白 */
const TILE_MARGIN: number = 2
const MAX_TILES: number = 120
/** 全览时轨迹四周留出的边距（vp），避免端点贴到屏幕边 */
const FIT_PAD: number = 44

class TilePos {
  tx: number = 0
  ty: number = 0

  constructor(tx: number, ty: number) {
    this.tx = tx
    this.ty = ty
  }
}

class RunMetric {
  label: string = ''
  value: string = ''

  constructor(label: string, value: string) {
    this.label = label
    this.value = value
  }
}

/**
 * 跑步详情页：天地图底图 + 轨迹折线 + 公里标记，下面是高驰指标面板。
 *
 * 瓦片走后端 /map/tile 代理（Key 在服务端），轨迹点已经抽稀到 700 个以内，
 * 所以手势只做「整幅挪动 + 层级切换」，不做连续小数缩放——那需要重画整片瓦片。
 */
@ComponentV2
export struct RunDetailPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local titleText: string = '跑步记录';
  @Local primary: RunMetric[] = [];
  @Local metrics: RunMetric[] = [];
  @Local points: RunTrackPoint[] = [];
  @Local marks: RunKmMark[] = [];
  @Local bbox: number[] = [];
  @Local noteText: string = '';
  @Local loading: boolean = true;
  @Local satellite: boolean = true;
  @Local tiles: TilePos[] = [];
  @Local zoom: number = 12;
  @Local centerX: number = 0;
  @Local centerY: number = 0;
  @Local dragX: number = 0;
  @Local dragY: number = 0;
  @Local pinch: number = 1;
  @Local viewW: number = 0;
  @Local viewH: number = 0;
  private mapCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();
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
      this.titleText = `${RunFmt.stamp(activity.startTimestamp, activity.activityDate)} · ${activity.sportName ?? '跑步'}`
      this.primary = [
        new RunMetric('距离', RunFmt.km(activity.distanceKm)),
        new RunMetric('时长', RunFmt.clock(activity.durationSeconds)),
        new RunMetric('平均配速', RunFmt.pace(activity.paceSeconds))
      ]
      this.metrics = this.metricsOf(activity)
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
        this.bbox = track.bbox === null ? [] : track.bbox
      }
    }).catch((err: Object) => {
      this.noteText = err instanceof Error ? err.message : '记录详情加载失败'
      toast(this.noteText)
    }).finally(() => {
      this.loading = false
      this.tryFit()
    })
  }

  private metricsOf(activity: RunActivity): RunMetric[] {
    const rows: RunMetric[] = []
    rows.push(new RunMetric('最快 1 公里', RunFmt.pace(activity.bestKmSeconds)))
    rows.push(new RunMetric('累计上升', activity.elevationGain === null ? '-' : activity.elevationGain + ' m'))
    rows.push(new RunMetric('消耗', activity.calories === null ? '-' : activity.calories + ' kcal'))
    rows.push(new RunMetric('平均心率', activity.avgHr === null ? '-' : activity.avgHr + ' bpm'))
    rows.push(new RunMetric('训练负荷', activity.trainingLoad === null ? '-' : activity.trainingLoad + ' TL'))
    rows.push(new RunMetric('平均步频', activity.avgCadence === null ? '-' : activity.avgCadence + ' 步/分'))
    rows.push(new RunMetric('平均功率', activity.avgPower === null ? '-' : activity.avgPower + ' W'))
    rows.push(new RunMetric('运动表现', activity.performance === null ? '-' : activity.performance))
    return rows
  }

  /* ---------------- 瓦片与坐标换算 ---------------- */

  private tileUrl(layer: string, tx: number, ty: number): string {
    return `${Session.serverUrl}/api/map/tile/${layer}/${this.zoom}/${tx}/${ty}`
  }

  private baseLayer(): string {
    return this.satellite ? 'img' : 'vec'
  }

  private labelLayer(): string {
    return this.satellite ? 'img_c' : 'vec_c'
  }

  private xOf(lon: number): number {
    return MapGeo.lonToX(lon, this.zoom)
  }

  private yOf(lat: number): number {
    return MapGeo.latToY(lat, this.zoom)
  }

  private screenX(lon: number): number {
    return this.xOf(lon) - this.shiftX()
  }

  private screenY(lat: number): number {
    return this.yOf(lat) - this.shiftY()
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

  /** 把轨迹缩放到刚好铺满地图区 */
  private fitTrack(): void {
    if (this.bbox.length < 4) {
      return
    }
    this.zoom = MapGeo.fitLevel(this.bbox, this.viewW, this.viewH, FIT_PAD, MIN_ZOOM, MAX_ZOOM)
    this.centerX = MapGeo.lonToX((this.bbox[0] + this.bbox[2]) / 2, this.zoom)
    this.centerY = (MapGeo.mercV(this.bbox[3]) + MapGeo.mercV(this.bbox[1])) / 2 * MapGeo.worldPx(this.zoom)
    this.dragX = 0
    this.dragY = 0
    this.pinch = 1
    this.rebuildTiles()
    this.draw()
  }

  /** 把视口中心放到指定经纬度的固定层级（没有轨迹时退回起点定位） */
  private centerOn(lon: number, lat: number, level: number): void {
    this.zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, level))
    this.centerX = MapGeo.lonToX(lon, this.zoom)
    this.centerY = MapGeo.latToY(lat, this.zoom)
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
    this.draw()
  }

  private commitDrag(): void {
    this.centerX -= this.dragX
    this.centerY -= this.dragY
    this.dragX = 0
    this.dragY = 0
    this.clampCenter()
    this.rebuildTiles()
    this.draw()
  }

  /* ---------------- 轨迹绘制 ---------------- */

  private draw(): void {
    const ctx = this.mapCtx
    ctx.clearRect(0, 0, ctx.width, ctx.height)
    const pts = this.points
    if (pts.length < 2) {
      return
    }

    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(this.screenX(pts[0].lon), this.screenY(pts[0].lat))
    for (let index = 1; index < pts.length; index += 1) {
      ctx.lineTo(this.screenX(pts[index].lon), this.screenY(pts[index].lat))
    }
    // 先描一条深色底线，影像底图上黄色线才不会糊掉
    ctx.lineWidth = 9
    ctx.strokeStyle = 'rgba(0,0,0,0.35)'
    ctx.stroke()
    ctx.lineWidth = 5
    ctx.strokeStyle = RunStyle.TRACK
    ctx.stroke()

    for (const mark of this.marks) {
      const x = this.screenX(mark.lon)
      const y = this.screenY(mark.lat)
      if (x < -20 || y < -20 || x > ctx.width + 20 || y > ctx.height + 20) {
        continue
      }
      ctx.beginPath()
      ctx.arc(x, y, 12, 0, Math.PI * 2)
      ctx.fillStyle = RunStyle.MARK_FILL
      ctx.fill()
      ctx.lineWidth = 1.5
      ctx.strokeStyle = RunStyle.MARK_EDGE
      ctx.stroke()
      ctx.fillStyle = RunStyle.MARK_TEXT
      ctx.font = '12px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(mark.km.toString(), x, y)
    }

    this.drawEndpoint(pts[0].lon, pts[0].lat, RunStyle.START)
    const last = pts[pts.length - 1]
    this.drawEndpoint(last.lon, last.lat, RunStyle.END)
  }

  private drawEndpoint(lon: number, lat: number, color: string): void {
    const ctx = this.mapCtx
    const x = this.screenX(lon)
    const y = this.screenY(lat)
    ctx.beginPath()
    ctx.arc(x, y, 8, 0, Math.PI * 2)
    ctx.fillStyle = color
    ctx.fill()
    ctx.lineWidth = 2
    ctx.strokeStyle = '#FFFFFF'
    ctx.stroke()
  }

  build() {
    Column() {
      PageHeader({ navStack: this.nav, title: this.titleText })

      Stack({ alignContent: Alignment.TopStart }) {
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

          Canvas(this.mapCtx)
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
            .onReady(() => {
              this.tryFit()
              this.draw()
            })
        }
        .width('100%')
        .height('100%')
        .scale({ x: this.pinch, y: this.pinch })

        if (!this.loading && this.points.length < 2) {
          Column() {
            Text(this.noteText.length > 0 ? this.noteText : '这条记录没有可显示的轨迹')
              .fontSize(AppFont.Caption)
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
              .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent)
        }

        Row() {
          Blank()
          Column({ space: AppSpace.Xs }) {
            this.mapButton(this.satellite ? '影像' : '矢量', (): void => {
              this.satellite = !this.satellite
            })
            this.mapButton('全览', (): void => {
              this.fitTrack()
            })
            this.mapButton('＋', (): void => {
              this.zoomBy(1)
            })
            this.mapButton('－', (): void => {
              this.zoomBy(-1)
            })
          }
        }
        .width('100%')
        .padding({ top: AppSpace.Sm, left: PAGE_PAD_H, right: PAGE_PAD_H })
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .onSizeChange((_oldValue: SizeOptions, newValue: SizeOptions) => {
        if (typeof newValue.width !== 'number' || typeof newValue.height !== 'number') {
          return
        }
        this.viewW = newValue.width
        this.viewH = newValue.height
        this.rebuildTiles()
        this.tryFit()
        this.draw()
      })
      .gesture(
        PanGesture({ fingers: 1, distance: 4 })
          .onActionUpdate((event: GestureEvent) => {
            this.dragX = event.offsetX
            this.dragY = event.offsetY
            this.draw()
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
            } else {
              this.draw()
            }
          })
      )

      this.dataPanel()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  mapButton(label: string, action: () => void) {
    Text(label)
      .fontSize(AppFont.Caption)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .textAlign(TextAlign.Center)
      .height(32)
      .constraintSize({ minWidth: 44 })
      .padding({ left: AppSpace.Sm, right: AppSpace.Sm })
      .borderRadius(AppRadius.Pill)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: AppColor.Divider })
      .onClick(() => {
        action()
      })
  }

  @Builder
  dataPanel() {
    Column() {
      if (this.loading) {
        Text('正在读取记录…')
          .fontSize(AppFont.Body)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .height(64)
          .textAlign(TextAlign.Center)
      } else {
        Row({ space: 10 }) {
          ForEach(this.primary, (item: RunMetric) => {
            Column({ space: 3 }) {
              Text(item.value)
                .fontSize(AppFont.TitleL)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.label)
                .fontSize(10)
                .fontColor($r('sys.color.font_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (item: RunMetric) => item.label)
        }
        .width('100%')
        .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm })

        Divider().color(AppColor.Divider)

        GridRow({ columns: 4, gutter: 8 }) {
          ForEach(this.metrics, (item: RunMetric) => {
            GridCol({ span: 1 }) {
              Column({ space: 2 }) {
                Text(item.value)
                  .fontSize(AppFont.Body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.label)
                  .fontSize(10)
                  .fontColor($r('sys.color.font_tertiary'))
                  .maxLines(1)
              }
              .width('100%')
              .padding({ top: AppSpace.Xs, bottom: AppSpace.Xs })
              .alignItems(HorizontalAlign.Center)
            }
          }, (item: RunMetric) => item.label)
        }
        .width('100%')
        .padding({ top: AppSpace.Xs, bottom: AppSpace.Sm })
      }
    }
    .width('100%')
    .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius({ topLeft: AppRadius.Lg, topRight: AppRadius.Lg })
  }
}

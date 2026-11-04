import { toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { MapGeo, RunFmt, RunStyle } from '../../common/Running'
import { AppColor, AppFont, AppRadius, AppSpace } from '../../theme/Theme'
import { RunActivity, RunDetailResult, RunKmMark, RunTrackPoint } from '../../model/Models'
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
/** 底部数据卡片大概占多高：全览时轨迹要落在卡片上方的可见区里 */
const PANEL_H: number = 236
/** 悬浮按钮的边长 */
const FLOAT_BTN: number = 40

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
  unit: string = ''

  constructor(label: string, value: string, unit: string = '') {
    this.label = label
    this.value = value
    this.unit = unit
  }
}

/**
 * 跑步详情页：整屏天地图 + 悬浮数据卡片，形制对齐高驰 app。
 *
 * 瓦片走后端 /map/tile 代理（Key 在服务端），轨迹点已经抽稀到 700 个以内，
 * 所以手势只做「整幅挪动 + 层级切换」，不做连续小数缩放——那需要重画整片瓦片。
 */
@ComponentV2
export struct RunDetailPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local titleText: string = '跑步记录';
  @Local subtitleText: string = '';
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
      this.titleText = RunFmt.title(activity.name, activity.sportName)
      this.subtitleText = RunFmt.stamp(activity.startTimestamp, activity.activityDate)
      this.primary = [
        new RunMetric('距离', RunFmt.km(activity.distanceKm), 'km'),
        new RunMetric('运动时间', RunFmt.clock(activity.durationSeconds)),
        new RunMetric('平均配速', RunFmt.pace(activity.paceSeconds), '/km')
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
    rows.push(new RunMetric('累计上升', activity.elevationGain === null ? '-' : activity.elevationGain.toString(), 'm'))
    rows.push(new RunMetric('消耗', activity.calories === null ? '-' : activity.calories.toString(), 'kcal'))
    rows.push(new RunMetric('平均心率', activity.avgHr === null ? '-' : activity.avgHr.toString(), 'bpm'))
    rows.push(new RunMetric('训练负荷', activity.trainingLoad === null ? '-' : activity.trainingLoad.toString(), 'TL'))
    rows.push(new RunMetric('平均步频', activity.avgCadence === null ? '-' : activity.avgCadence.toString(), '步/分'))
    rows.push(new RunMetric('平均功率', activity.avgPower === null ? '-' : activity.avgPower.toString(), 'W'))
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
    return Math.max(this.viewH - PANEL_H, 160)
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
      + PANEL_H / 2
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
    this.centerY = MapGeo.latToY(lat, this.zoom) + PANEL_H / 2
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
    ctx.lineWidth = 6
    ctx.strokeStyle = 'rgba(0,0,0,0.30)'
    ctx.stroke()
    ctx.lineWidth = 3.5
    ctx.strokeStyle = RunStyle.TRACK
    ctx.stroke()

    for (const mark of this.marks) {
      const x = this.screenX(mark.lon)
      const y = this.screenY(mark.lat)
      if (x < -20 || y < -20 || x > ctx.width + 20 || y > ctx.height + 20) {
        continue
      }
      ctx.beginPath()
      ctx.arc(x, y, 9, 0, Math.PI * 2)
      ctx.fillStyle = RunStyle.MARK_FILL
      ctx.fill()
      ctx.lineWidth = 1
      ctx.strokeStyle = RunStyle.MARK_EDGE
      ctx.stroke()
      ctx.fillStyle = RunStyle.MARK_TEXT
      ctx.font = '11px sans-serif'
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
    ctx.arc(x, y, 6, 0, Math.PI * 2)
    ctx.fillStyle = color
    ctx.fill()
    ctx.lineWidth = 2
    ctx.strokeStyle = '#FFFFFF'
    ctx.stroke()
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

      // 顶部：返回按钮在左，右侧留空给状态栏
      Row() {
        this.backButton()
      }
      .width('100%')
      .padding({ top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm, left: AppSpace.Md })
      .hitTestBehavior(HitTestMode.Transparent)

      // 右侧悬浮控制
      Row() {
        Blank()
        Column({ space: AppSpace.Sm }) {
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
        .alignItems(HorizontalAlign.End)
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
            .fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
        }
        .width('100%')
        .padding({ bottom: PANEL_H })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      this.dataPanel()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  backButton() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor('#1F2937')
        .fontWeight(FontWeight.Bold)
        .width(26)
        .textAlign(TextAlign.Center)
    }
    .width(FLOAT_BTN)
    .height(FLOAT_BTN)
    .borderRadius(FLOAT_BTN / 2)
    .backgroundColor('#E6FFFFFF')
    .shadow({ radius: 8, color: '#33000000', offsetY: 2 })
    .onClick(() => {
      this.nav.pop()
    })
  }

  @Builder
  mapButton(label: string, action: () => void) {
    Text(label)
      .fontSize(AppFont.Caption)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1F2937')
      .textAlign(TextAlign.Center)
      .width(FLOAT_BTN)
      .height(FLOAT_BTN)
      .borderRadius(FLOAT_BTN / 2)
      .backgroundColor('#E6FFFFFF')
      .shadow({ radius: 8, color: '#33000000', offsetY: 2 })
      .onClick(() => {
        action()
      })
  }

  @Builder
  dataPanel() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text(this.titleText)
            .fontSize(AppFont.Title)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitleText)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (this.loading) {
        Text('正在读取记录…')
          .fontSize(AppFont.Body)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .height(64)
          .textAlign(TextAlign.Center)
      } else {
        Row({ space: 8 }) {
          ForEach(this.primary, (item: RunMetric) => {
            Column({ space: 2 }) {
              Row({ space: 3 }) {
                Text(item.value)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (item.unit.length > 0) {
                  Text(item.unit)
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                }
              }
              Text(item.label)
                .fontSize(10)
                .fontColor($r('sys.color.font_secondary'))
                .maxLines(1)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (item: RunMetric) => item.label)
        }
        .width('100%')
        .margin({ top: AppSpace.Sm, bottom: AppSpace.Sm })

        Divider().color(AppColor.Divider)

        GridRow({ columns: 4, gutter: 8 }) {
          ForEach(this.metrics, (item: RunMetric) => {
            GridCol({ span: 1 }) {
              Column({ space: 2 }) {
                Row({ space: 2 }) {
                  Text(item.value)
                    .fontSize(AppFont.Body)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (item.unit.length > 0) {
                    Text(item.unit)
                      .fontSize(9)
                      .fontColor($r('sys.color.font_tertiary'))
                  }
                }
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
    .padding({ left: AppSpace.Md, right: AppSpace.Md, top: AppSpace.Sm, bottom: AppSpace.Sm })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius({ topLeft: AppRadius.Xl, topRight: AppRadius.Xl })
    .shadow({ radius: 16, color: '#22000000', offsetY: -4 })
    .margin({ left: AppSpace.Sm, right: AppSpace.Sm, bottom: AppSpace.Sm })
    .hitTestBehavior(HitTestMode.Block)
  }
}

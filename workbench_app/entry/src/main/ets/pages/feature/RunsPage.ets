import { toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { MapGeo, RunFmt, RunStyle } from '../../common/Running'
import { AppColor, AppFont, AppRadius, AppSpace } from '../../theme/Theme'
import { CorosStatus, RunItem, RunListResult, RunMonth } from '../../model/Models'
import { EmptyView, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, PillButton, TechCard } from '../../components/Ui'

/** 列表右侧轨迹格子的尺寸：够看出「绕了一圈」还是「一条直线」 */
const THUMB_W: number = 92
const THUMB_H: number = 62
/** 同步进度轮询间隔与上限（全部历史可能要几分钟，到点就停手，让用户重新触发） */
const SYNC_POLL_MS: number = 2500
const SYNC_POLL_LIMIT: number = 200

/** 轨迹缩略图：服务端已抽稀到十几个点，这里只做等比贴合后画折线和起终点 */
@ComponentV2
struct TrackThumb {
  @Param points: number[][] = [];
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  private draw(): void {
    const ctx = this.ctx
    const width = ctx.width
    const height = ctx.height
    ctx.clearRect(0, 0, width, height)

    const pts = this.points
    if (pts.length === 0) {
      return
    }

    let minLon = pts[0][0]
    let maxLon = pts[0][0]
    let minV = MapGeo.mercV(pts[0][1])
    let maxV = minV
    for (const point of pts) {
      minLon = Math.min(minLon, point[0])
      maxLon = Math.max(maxLon, point[0])
      const v = MapGeo.mercV(point[1])
      minV = Math.min(minV, v)
      maxV = Math.max(maxV, v)
    }

    // 经度先归一到「世界宽度的比例」，纵向用墨卡托比例，两者同为 0~1 的世界比例，
    // 和详情页的底图是同一套投影，路形才不会被横向拉长
    const pad = 10
    const spanX = Math.max((maxLon - minLon) / 360, 1e-7)
    const spanV = Math.max(maxV - minV, 1e-7)
    const scale = Math.min((width - pad * 2) / spanX, (height - pad * 2) / spanV)
    const offsetX = (width - spanX * scale) / 2
    const offsetY = (height - spanV * scale) / 2
    const xOf = (lon: number): number => offsetX + ((lon - minLon) / 360) * scale
    const yOf = (lat: number): number => offsetY + (maxV - MapGeo.mercV(lat)) * scale

    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    ctx.beginPath()
    for (let index = 0; index < pts.length; index += 1) {
      const x = xOf(pts[index][0])
      const y = yOf(pts[index][1])
      if (index === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
    }
    // 浅底卡片上黄色线不显眼，先垫一条白边
    ctx.lineWidth = 4
    ctx.strokeStyle = '#FFFFFFFF'
    ctx.stroke()
    ctx.lineWidth = 2
    ctx.strokeStyle = RunStyle.TRACK
    ctx.stroke()

    ctx.fillStyle = RunStyle.START
    ctx.beginPath()
    ctx.arc(xOf(pts[0][0]), yOf(pts[0][1]), 3, 0, Math.PI * 2)
    ctx.fill()

    const last = pts[pts.length - 1]
    ctx.fillStyle = RunStyle.END
    ctx.beginPath()
    ctx.arc(xOf(last[0]), yOf(last[1]), 3, 0, Math.PI * 2)
    ctx.fill()
  }

  build() {
    Canvas(this.ctx)
      .width(THUMB_W)
      .height(THUMB_H)
      .borderRadius(AppRadius.Sm)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .hitTestBehavior(HitTestMode.None)
      .onReady(() => {
        this.draw()
      })
  }
}

/**
 * 跑步记录页：高驰同步下来的活动按月分组，形制对齐高驰 app 的记录列表。
 * 下拉 = 同步最近 30 天（新的累加、旧的原样覆盖），全部历史在概览卡里手动触发。
 */
@ComponentV2
export struct RunsPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local months: RunMonth[] = [];
  @Local totalCount: number = 0;
  @Local totalKm: number = 0;
  @Local totalSeconds: number = 0;
  @Local loading: boolean = true;
  @Local refreshing: boolean = false;
  @Local syncing: boolean = false;
  @Local syncNote: string = '';
  @Local connected: boolean = true;
  /** 参与列表项 key：同步成功后让缩略图 Canvas 重新走一次 onReady */
  @Local revision: number = 0;
  private pollTimer: number = 0;
  private pollCount: number = 0;

  aboutToAppear(): void {
    this.reload()
  }

  aboutToDisappear(): void {
    this.stopPoll()
  }

  private reload(): void {
    Api.runningActivities('running').then((data: RunListResult) => {
      this.months = data.months
      this.totalCount = data.total
      this.totalKm = data.distanceKm
      this.totalSeconds = data.durationSeconds
      this.revision += 1
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载跑步记录失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })

    Api.corosStatus().then((status: CorosStatus) => {
      this.connected = status.connected
      if (status.sync.status === 'running' && !this.syncing) {
        this.syncing = true
        this.pollSync()
      }
    }).catch(() => {
      // 状态只影响提示文案，列表能出来就不打扰
    })
  }

  private startSync(history: boolean): void {
    if (this.syncing) {
      return
    }
    this.syncing = true
    this.pollCount = 0
    this.syncNote = history ? '正在逐月翻查高驰全部历史…' : '正在同步高驰最近 30 天…'
    Api.syncCoros(30, history).then(() => {
      this.pollSync()
    }).catch((err: Object) => {
      const message = err instanceof Error ? err.message : '同步请求失败'
      // 另一端（网页）已经发起同步就接着看进度，其余失败原因直接告诉用户
      if (message.indexOf('正在同步') >= 0) {
        this.pollSync()
        return
      }
      this.syncing = false
      this.syncNote = ''
      this.refreshing = false
      toast(message)
    })
  }

  private pollSync(): void {
    this.stopPoll()
    if (this.pollCount >= SYNC_POLL_LIMIT) {
      this.syncing = false
      this.syncNote = '同步耗时较长，稍后下拉刷新查看结果'
      this.refreshing = false
      return
    }
    this.pollCount += 1
    this.pollTimer = setTimeout(() => {
      this.pollTimer = 0
      Api.corosStatus().then((status: CorosStatus) => {
        if (status.sync.status === 'running') {
          this.pollSync()
          return
        }
        this.connected = status.connected
        this.syncing = false
        this.syncNote = this.summaryOf(status)
        this.reload()
      }).catch((err: Object) => {
        this.syncing = false
        this.syncNote = err instanceof Error ? err.message : '同步状态获取失败'
        this.refreshing = false
      })
    }, SYNC_POLL_MS)
  }

  private stopPoll(): void {
    if (this.pollTimer !== 0) {
      clearTimeout(this.pollTimer)
      this.pollTimer = 0
    }
  }

  private summaryOf(status: CorosStatus): string {
    if (!status.connected) {
      return '尚未连接高驰账号，请先在网页端「跑步专项」完成授权'
    }
    const result = status.sync.result
    if (result === null) {
      return '同步已结束'
    }
    if (status.sync.status === 'failed') {
      const first = result.errors.length > 0 ? result.errors[0].message : '未知原因'
      return '同步失败：' + first
    }
    const parts: string[] = ['活动 ' + result.activities, '详情 ' + result.details, '轨迹 ' + result.tracks]
    const tail = result.errors.length > 0 ? '（' + result.errors[0].tool + '：' + result.errors[0].message + '）' : ''
    return '同步完成 ' + parts.join(' · ') + tail
  }

  private openDetail(item: RunItem): void {
    AppStorage.setOrCreate('runDetailLabelId', item.labelId)
    this.nav.pushPathByName('runDetail', null)
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({ navStack: this.nav, title: '跑步记录' })

            this.overviewCard()

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.totalCount === 0) {
              EmptyView({
                icon: '🏃',
                text: this.connected
                  ? '还没有跑步记录，点上方「同步近 30 天」即可从高驰取回'
                  : '还没有跑步记录，先在网页端连接高驰账号'
              })
            } else {
              ForEach(this.months, (month: RunMonth) => {
                Column() {
                  this.monthHeader(month)
                  ForEach(month.items, (item: RunItem) => {
                    Column() {
                      this.recordRow(item)
                    }
                    .width('100%')
                    .margin({ bottom: AppSpace.Xs })
                  }, (item: RunItem) => item.labelId + '-' + this.revision.toString())
                }
                .width('100%')
                .margin({ top: AppSpace.Md })
              }, (month: RunMonth) => month.month)
            }
          }
          .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: PAGE_SCROLL_BOTTOM })
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.startSync(false)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  overviewCard() {
    TechCard() {
      Column({ space: AppSpace.Xs }) {
        Row({ space: 10 }) {
          this.metric('总里程', RunFmt.km(this.totalKm) + ' km')
          this.metric('总次数', this.totalCount + ' 次')
          this.metric('总时长', RunFmt.hours(this.totalSeconds) + ' h')
        }
        .width('100%')

        Row({ space: AppSpace.Xs }) {
          PillButton({
            label: this.syncing ? '同步中…' : '同步近 30 天',
            onTap: (): void => {
              this.startSync(false)
            }
          })
          PillButton({
            label: '拉取全部历史',
            filled: false,
            onTap: (): void => {
              this.startSync(true)
            }
          })
        }
        .width('100%')
        .margin({ top: AppSpace.Xxs })

        if (this.syncNote.length > 0) {
          Text(this.syncNote)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  metric(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.Brand)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(10)
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .padding({ top: AppSpace.Xs, bottom: AppSpace.Xs })
    .borderRadius(AppRadius.Md)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .alignItems(HorizontalAlign.Center)
  }

  /** 月份分组头：左侧月份，右侧本月里程/次数/时长 */
  @Builder
  monthHeader(month: RunMonth) {
    Row({ space: AppSpace.Xs }) {
      Column()
        .width(3)
        .height(14)
        .borderRadius(2)
        .backgroundColor(AppColor.Brand)
      Text(month.label)
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Blank()
      Text(RunFmt.km(month.distanceKm) + ' km · ' + month.count + ' 次 · '
        + RunFmt.hours(month.durationSeconds) + ' 小时')
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .margin({ bottom: AppSpace.Xs })
  }

  @Builder
  recordRow(item: RunItem) {
    TechCard({ onCard: (): void => {
      this.openDetail(item)
    } }) {
      Row({ space: AppSpace.Sm }) {
        Column({ space: 4 }) {
          Text(RunFmt.title(item.name, item.sportName))
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(RunFmt.stamp(item.startTimestamp, item.activityDate))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
          Row({ space: AppSpace.Xs }) {
            Text(RunFmt.km(item.distanceKm) + ' km')
              .fontSize(AppFont.Body)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.Brand)
            Text('配速 ' + RunFmt.pace(item.paceSeconds))
              .fontSize(11)
              .fontColor($r('sys.color.font_secondary'))
            Text('时长 ' + RunFmt.clock(item.durationSeconds))
              .fontSize(11)
              .fontColor($r('sys.color.font_secondary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (item.thumb.length >= 2) {
          TrackThumb({ points: item.thumb })
        } else {
          Column() {
            Text('无轨迹')
              .fontSize(10)
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width(THUMB_W)
          .height(THUMB_H)
          .borderRadius(AppRadius.Sm)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }
}

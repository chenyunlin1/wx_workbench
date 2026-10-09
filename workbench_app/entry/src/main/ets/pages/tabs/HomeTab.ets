import { Fmt, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Session, SessionStore } from '../../store/Session'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppSpace } from '../../theme/Theme'
import { WindowUtils } from '../../utils/WindowUtils'
import { DashboardSummary, Habit, Interview, Schedule, ShoppingItem } from '../../model/Models'
import { SectionTitle, StatTile, TechCard } from '../../components/Ui'

class FeatureEntry {
  icon: string = ''
  label: string = ''
  target: string = ''

  constructor(icon: string, label: string, target: string) {
    this.icon = icon
    this.label = label
    this.target = target
  }
}

const ENTRIES: FeatureEntry[] = [
  new FeatureEntry('📅', '日程管理', 'schedules'),
  new FeatureEntry('✅', '习惯健康', 'habits'),
  new FeatureEntry('🏋️', '减脂健身', 'workout'),
  new FeatureEntry('💰', '财务记账', 'finance'),
  new FeatureEntry('🎬', '书影音收藏', 'collection'),
  new FeatureEntry('🧠', '知识练习', 'practice'),
  new FeatureEntry('💼', '面试准备', 'interviews'),
  new FeatureEntry('🛒', '待买清单', 'shopping')
]

/** 首页竖向节奏：区块之间统一 SECTION_GAP；区块内并列元素（指标块、功能格子）统一 TILE_GAP */
const SECTION_GAP: number = 16
const TILE_GAP: number = 10

@ComponentV2
export struct HomeTab {
  @Param nav: NavPathStack = new NavPathStack();
  @Event onScrollerReady: (scroller: Scroller) => void = () => {};
  @Local session: SessionStore = Session;
  @Local summary: DashboardSummary | null = null;
  @Local refreshing: boolean = false;
  @Local todaySchedules: Schedule[] = [];

  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.onScrollerReady(this.scroller);
    this.reload();
  }

  @Monitor('session.dataVersion')
  onDataVersionChange(): void {
    this.reload();
  }

  private reload(): void {
    Api.getDashboard().then((data: DashboardSummary) => {
      this.summary = data
      const today = Fmt.today()
      const list: Schedule[] = []
      for (const item of data.schedules) {
        if (Fmt.dateOnly(item.startTime) === today) {
          list.push(item)
        }
      }
      this.todaySchedules = list.sort((a: Schedule, b: Schedule) => a.startTime.localeCompare(b.startTime))
    }).catch((err: Object) => {
      const msg = err instanceof Error ? err.message : '加载失败'
      toast(msg)
    }).finally(() => {
      this.refreshing = false
    })
  }

  private greeting(): string {
    const hour = new Date().getHours()
    if (hour < 6) {
      return '夜深了'
    }
    if (hour < 11) {
      return '早上好'
    }
    if (hour < 14) {
      return '中午好'
    }
    if (hour < 18) {
      return '下午好'
    }
    return '晚上好'
  }

  @Builder
  todayScheduleRow(item: Schedule) {
    Row({ space: 10 }) {
      Column() {
        Text(Fmt.timeOnly(item.startTime))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.Brand)
      }
      .width(52)
      Column()
        .width(2)
        .height(30)
        .borderRadius(1)
        .backgroundColor(Theme.priorityColor(item.priority))
      Column({ space: 2 }) {
        Text(item.title)
          .fontSize(AppFont.Body)
          .fontColor(item.completed ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
          .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.category + ' · ' + Theme.priorityLabel(item.priority) + '优先')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (item.completed) {
        Text('已完成')
          .fontSize(10)
          .fontColor(AppColor.Brand)
      }
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .onClick(() => {
      this.nav.pushPathByName('schedules', null)
    })
  }

  private latestWeightText(): string {
    if (this.summary === null || this.summary.health.latestWeight === null) {
      return '-'
    }
    return this.summary.health.latestWeight + ' kg'
  }

  private sevenDayAverageText(): string {
    if (this.summary === null || this.summary.health.sevenDayAverage === null) {
      return '暂无 7 日均值'
    }
    return '7 日均值 ' + this.summary.health.sevenDayAverage.toFixed(1)
  }

  private pendingCountText(): string {
    if (this.summary === null) {
      return '-'
    }
    const count = this.summary.shopping.filter((s: ShoppingItem) => s.status === 'pending').length
    return count.toString() + ' 件'
  }

  private pendingShoppingNames(): string {
    if (this.summary === null) {
      return '暂无待买'
    }
    const pending = this.summary.shopping.filter((s: ShoppingItem) => s.status === 'pending')
    if (pending.length === 0) {
      return '全部买齐了 ✨'
    }
    const names: string[] = []
    for (const item of pending.slice(0, 3)) {
      names.push(item.name)
    }
    return names.join('、')
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll(this.scroller) {
          Column({ space: SECTION_GAP }) {
            // 顶部问候
            Row({ space: AppSpace.Sm }) {
              Column({ space: 3 }) {
                Text(Fmt.today() + ' · ' + Fmt.weekday(Fmt.today()))
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
                Text(this.greeting() + '，' + Session.username())
                  .fontSize(AppFont.TitleL)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(Session.username().substring(0, 1).toUpperCase())
                .fontSize(AppFont.Title)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.OnBrand)
                .width(42)
                .height(42)
                .textAlign(TextAlign.Center)
                .borderRadius(21)
                .backgroundColor(AppColor.Brand)
            }
            .width('100%')

            // 今日核心指标：每块指标点对应功能页，和下方「全部功能」格子一致
            Column({ space: TILE_GAP }) {
              Row({ space: TILE_GAP }) {
                StatTile({
                  weighted: true,
                  icon: '📅',
                  value: this.summary === null ? '-' : this.todaySchedules.length.toString() + ' 项',
                  label: '今日日程',
                  accent: AppColor.Brand,
                  onTile: (): void => {
                    this.nav.pushPathByName('schedules', null)
                  }
                })
                StatTile({
                  weighted: true,
                  icon: '✅',
                  value: this.summary === null ? '-' :
                  this.summary.habits.filter((h: Habit) => h.checkedToday).length.toString() + '/' +
                  this.summary.habits.length.toString(),
                  label: '习惯打卡',
                  accent: AppColor.BrandDark,
                  onTile: (): void => {
                    this.nav.pushPathByName('habits', null)
                  }
                })
              }
              .width('100%')
              Row({ space: TILE_GAP }) {
                StatTile({
                  weighted: true,
                  icon: '📚',
                  value: this.summary === null ? '-' : this.summary.learning.todayDuration + ' 分钟',
                  label: '今日学习',
                  accent: AppColor.Brand,
                  onTile: (): void => {
                    this.nav.pushPathByName('practice', null)
                  }
                })
                StatTile({
                  weighted: true,
                  icon: '💼',
                  value: this.summary === null ? '-' :
                  this.summary.interviews.filter((i: Interview) => i.status === 'pending').length.toString() + ' 场',
                  label: '待进行面试',
                  accent: Theme.WARN,
                  onTile: (): void => {
                    this.nav.pushPathByName('interviews', null)
                  }
                })
              }
              .width('100%')
            }
            .width('100%')

            // 本月财务
            Column() {
              SectionTitle({ title: '本月收支' })
              TechCard({ onCard: (): void => {
                this.nav.pushPathByName('finance', null)
              } }) {
                Row() {
                  Column({ space: 4 }) {
                    Text('收入')
                      .fontSize(11)
                      .fontColor($r('sys.color.font_secondary'))
                    Text('+' + (this.summary === null ? '-' : Fmt.moneyShort(this.summary.finance.income)))
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.SUCCESS)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 4 }) {
                    Text('支出')
                      .fontSize(11)
                      .fontColor($r('sys.color.font_secondary'))
                    Text('-' + (this.summary === null ? '-' : Fmt.moneyShort(this.summary.finance.expense)))
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.DANGER)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 4 }) {
                    Text('结余')
                      .fontSize(11)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.summary === null ? '-' : Fmt.moneyShort(this.summary.finance.balance))
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                }
                .width('100%')
              }
            }
            .width('100%')

            // 今日日程
            Column() {
              SectionTitle({ title: '今日日程' })
              if (this.todaySchedules.length === 0) {
                Text('今天没有安排，好好休息 🍵')
                  .fontSize(AppFont.Caption)
                  .fontColor($r('sys.color.font_tertiary'))
                  .width('100%')
                  .padding({ top: AppSpace.Xs, bottom: AppSpace.Xs })
              } else {
                ForEach(this.todaySchedules.slice(0, 4), (item: Schedule) => {
                  this.todayScheduleRow(item)
                }, (item: Schedule) => item.id.toString())
                if (this.todaySchedules.length > 4) {
                  Text('还有 ' + (this.todaySchedules.length - 4) + ' 条，点击查看全部 →')
                    .fontSize(11)
                    .fontColor(AppColor.Brand)
                    .margin({ top: 6 })
                    .onClick(() => {
                      this.nav.pushPathByName('schedules', null)
                    })
                }
              }
            }
            .width('100%')

            // 体重与待买（合并为一张卡片）
            TechCard() {
              Row({ space: 14 }) {
                Column({ space: 6 }) {
                  Text('⚖️ 最新体重')
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                  Text(this.latestWeightText())
                    .fontSize(AppFont.Title)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColor.Brand)
                  Text(this.sevenDayAverageText())
                    .fontSize(10)
                    .fontColor($r('sys.color.font_tertiary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => {
                  this.nav.pushPathByName('habits', null)
                })
                Divider()
                  .vertical(true)
                  .height(46)
                  .color(Theme.BORDER)
                Column({ space: 6 }) {
                  Text('🛒 待买清单')
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                  Text(this.pendingCountText())
                    .fontSize(AppFont.Title)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.WARN)
                  Text(this.pendingShoppingNames())
                    .fontSize(10)
                    .fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => {
                  this.nav.pushPathByName('shopping', null)
                })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }

            // 功能入口
            Column() {
              SectionTitle({ title: '全部功能' })
              GridRow({ columns: 4, gutter: TILE_GAP }) {
                ForEach(ENTRIES, (entry: FeatureEntry) => {
                  GridCol({ span: 1 }) {
                    Column({ space: AppSpace.Xs }) {
                      Text(entry.icon)
                        .fontSize(30)
                      Text(entry.label)
                        .fontSize(11)
                        .fontColor($r('sys.color.font_primary'))
                        .maxLines(1)
                    }
                    .width('100%')
                    .padding({ top: 10, bottom: 10 })
                    .onClick(() => {
                      this.nav.pushPathByName(entry.target, null)
                    })
                  }
                }, (entry: FeatureEntry) => entry.target)
              }
              .width('100%')
            }
            .width('100%')
          }
          .padding({
            left: AppSpace.Md,
            right: AppSpace.Md,
            top: WindowUtils.getStatusBarHeightVp() + 12,
            bottom: WindowUtils.getFloatingTabBottomVp()
          })
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.reload()
      })
    }
    .width('100%')
    .height('100%')
  }
}

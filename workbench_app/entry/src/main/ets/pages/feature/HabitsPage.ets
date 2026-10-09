import { Fmt, toast } from '../../common/AppKit'
import { Api, HabitPayload, HealthPayload } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { HabitRecentDay, HabitStatItem, HabitStats, WeightRecord } from '../../model/Models'
import { EmptyView, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, PillButton, SectionTitle, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StatTile, TechCard } from '../../components/Ui'

const HABIT_ICONS: string[] = ['💧', '🏃', '📚', '💪', '🧘', '🥗', '😴', '☀️', '📝', '🎯']

@ComponentV2
export struct HabitsPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local stats: HabitStats | null = null;
  @Local weights: WeightRecord[] = [];
  @Local refreshing: boolean = false;
  @Local loading: boolean = true;
  // 习惯表单
  @Local showHabitForm: boolean = false;
  @Local habitFormId: number = 0;
  @Local habitName: string = '';
  @Local habitIconIndex: number = 0;
  // 体重表单
  @Local showWeightForm: boolean = false;
  @Local weightFormId: number = 0;
  @Local weightValue: string = '';
  @Local weightDate: string = Fmt.today();

  aboutToAppear(): void {
    this.reload()
  }

  private reload(): void {
    Api.habitStats(14).then((data: HabitStats) => {
      this.stats = data
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    })
    Api.listHealth().then((list: WeightRecord[]) => {
      this.weights = list
    }).catch(() => {
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private latestWeight(): WeightRecord | null {
    if (this.weights.length === 0) {
      return null
    }
    return this.weights[0]
  }

  private latestWeightText(): string {
    const latest = this.latestWeight()
    return latest === null ? '-' : latest.weight + ' kg'
  }

  private weightDelta(): number {
    if (this.weights.length < 2) {
      return 0
    }
    return this.weights[0].weight - this.weights[1].weight
  }

  private toggleCheckIn(item: HabitStatItem): void {
    const call = item.checkedToday ? Api.cancelCheckIn(item.id) : Api.checkInHabit(item.id)
    call.then(() => {
      toast(item.checkedToday ? '已取消今日打卡' : '打卡成功 🔥')
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '操作失败')
    })
  }

  private openHabitCreate(): void {
    this.habitFormId = 0
    this.habitName = ''
    this.habitIconIndex = 0
    this.showHabitForm = true
  }

  private openHabitEdit(item: HabitStatItem): void {
    this.habitFormId = item.id
    this.habitName = item.name
    this.habitIconIndex = Math.max(0, HABIT_ICONS.indexOf(item.icon))
    this.showHabitForm = true
  }

  private saveHabit(): void {
    if (this.habitName.trim().length === 0) {
      toast('请输入习惯名称')
      return
    }
    const payload: HabitPayload = { name: this.habitName.trim(), icon: HABIT_ICONS[this.habitIconIndex] }
    const call = this.habitFormId === 0
      ? Api.createHabit(payload)
      : Api.updateHabit(this.habitFormId, payload)
    call.then(() => {
      toast('已保存')
      this.showHabitForm = false
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    })
  }

  private removeHabit(id: number): void {
    Api.deleteHabit(id).then(() => {
      toast('已删除')
      this.showHabitForm = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  private openWeightCreate(): void {
    this.weightFormId = 0
    this.weightValue = ''
    this.weightDate = Fmt.today()
    this.showWeightForm = true
  }

  private openWeightEdit(record: WeightRecord): void {
    this.weightFormId = record.id
    this.weightValue = record.weight.toString()
    this.weightDate = record.recordDate
    this.showWeightForm = true
  }

  private pickWeightDate(): void {
    const base = this.weightDate.length === 10 ? Fmt.parse(this.weightDate + ' 09:00:00') : new Date()
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2035, 11, 31),
      selected: base,
      onDateAccept: (value: Date) => {
        this.weightDate = Fmt.date(value)
      }
    })
  }

  private saveWeight(): void {
    const weight = parseFloat(this.weightValue)
    if (isNaN(weight) || weight <= 0 || weight > 500) {
      toast('请输入有效的体重（kg）')
      return
    }
    const payload: HealthPayload = { weight: weight, recordDate: this.weightDate }
    const call = this.weightFormId === 0
      ? Api.createHealth(payload)
      : Api.updateHealth(this.weightFormId, payload)
    call.then(() => {
      toast('已保存')
      this.showWeightForm = false
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    })
  }

  private removeWeight(id: number): void {
    Api.deleteHealth(id).then(() => {
      toast('已删除')
      this.showWeightForm = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({ navStack: this.nav, title: '习惯健康' })

            // 概览
            Row({ space: 10 }) {
              StatTile({ weighted: true,
                icon: '🎯',
                value: this.stats === null ? '-' :
                this.stats.today.checked + '/' + this.stats.today.total,
                label: '今日打卡',
                accent: AppColor.Brand
              })
              StatTile({ weighted: true,
                icon: '📈',
                value: this.stats === null ? '-' : Math.round(this.stats.week.rate * 100) + '%',
                label: '本周完成率',
                accent: AppColor.Brand
              })
            }
            .width('100%')
            Row({ space: 10 }) {
              StatTile({ weighted: true,
                icon: '🔥',
                value: this.stats === null ? '-' : this.stats.longestStreak + ' 天',
                label: '最长连续',
                accent: Theme.WARN
              })
              StatTile({ weighted: true,
                icon: '✅',
                value: this.stats === null ? '-' : this.stats.totalChecked.toString(),
                label: '近14天打卡',
                accent: AppColor.BrandDark
              })
            }
            .width('100%')
            .margin({ top: 10 })

            // 习惯区
            Column() {
              SectionTitle({ title: '我的习惯' })
              Text('＋ 新习惯')
                .fontSize(AppFont.Caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.OnBrand)
                .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
            }
            .width('100%')
            .margin({ top: 18 })
            .onClick(() => {
              this.openHabitCreate()
            })

            if (this.stats === null || this.stats.habits.length === 0) {
              EmptyView({ icon: '🌱', text: '还没有习惯，点上方按钮创建' })
            } else {
              ForEach(this.stats.habits, (item: HabitStatItem) => {
                Column() {
                TechCard() {
                  Row({ space: AppSpace.Sm }) {
                    Text(item.icon)
                      .fontSize(26)
                    Column({ space: 5 }) {
                      Row({ space: AppSpace.Xs }) {
                        Text(item.name)
                          .fontSize(AppFont.BodyL)
                          .fontWeight(FontWeight.Bold)
                          .fontColor($r('sys.color.font_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text('🔥 ' + item.streakDays)
                          .fontSize(11)
                          .fontColor(Theme.WARN)
                      }
                      .width('100%')
                      Row({ space: 5 }) {
                        ForEach(item.recent, (day: HabitRecentDay) => {
                          Column()
                            .width(12)
                            .height(12)
                            .borderRadius(3)
                            .backgroundColor(day.checked ? AppColor.Brand : AppColor.Divider)
                        }, (day: HabitRecentDay) => day.date)
                      }
                      Text('本周 ' + item.weekCount + '/7 · 完成率 ' + Math.round(item.rate * 100) + '%')
                        .fontSize(10)
                        .fontColor($r('sys.color.font_tertiary'))
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Column({ space: 6 }) {
                      PillButton({
                        label: item.checkedToday ? '已打卡' : '打 卡',
                        filled: !item.checkedToday,
                        onTap: (): void => {
                          this.toggleCheckIn(item)
                        }
                      })
                      Text('✎')
                        .fontSize(AppFont.BodyL)
                        .fontColor($r('sys.color.font_tertiary'))
                        .onClick(() => {
                          this.openHabitEdit(item)
                        })
                    }
                  }
                  .width('100%')
                }
                }
                  .width('100%')
                .margin({ bottom: AppSpace.Xs })
              }, (item: HabitStatItem) => item.id.toString() + '-' + item.checkedToday.toString())
            }

            // 体重
            Row({ space: AppSpace.Xs }) {
              Column() {
                SectionTitle({ title: '健康体重' })
              }
              .layoutWeight(1)
              Text('＋ 记录')
                .fontSize(AppFont.Caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.OnBrand)
                .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
                .margin({ bottom: 10 })
                .onClick(() => {
                  this.openWeightCreate()
                })
            }
            .width('100%')
            .margin({ top: 14 })

            if (this.weights.length === 0) {
              EmptyView({ icon: '⚖️', text: '还没有体重记录' })
            } else {
              Column() {
              TechCard() {
                Row({ space: 14 }) {
                  Column({ space: 4 }) {
                    Text('最新体重')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.latestWeightText())
                      .fontSize(19)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 4 }) {
                    Text('较上次')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text((this.weightDelta() >= 0 ? '+' : '') + this.weightDelta().toFixed(1) + ' kg')
                      .fontSize(19)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.weightDelta() > 0 ? Theme.DANGER : this.weightDelta() < 0 ? Theme.SUCCESS : $r('sys.color.font_secondary'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 4 }) {
                    Text('记录数')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.weights.length.toString())
                      .fontSize(19)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
              }
              }
                .width('100%')
              .margin({ bottom: AppSpace.Xs })

              ForEach(this.weights.slice(0, 15), (record: WeightRecord, index: number) => {
                Row({ space: 10 }) {
                  Text(Fmt.dateOnly(record.recordDate))
                    .fontSize(AppFont.Caption)
                    .fontColor($r('sys.color.font_secondary'))
                    .layoutWeight(1)
                  Text(record.weight.toFixed(1) + ' kg')
                    .fontSize(AppFont.Body)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                  if (index < Math.min(15, this.weights.length) - 1) {
                    Text((record.weight - this.weights[index + 1].weight >= 0 ? '+' : '') +
                    (record.weight - this.weights[index + 1].weight).toFixed(1))
                      .fontSize(11)
                      .fontColor(record.weight - this.weights[index + 1].weight > 0 ? Theme.DANGER : Theme.SUCCESS)
                      .width(52)
                      .textAlign(TextAlign.End)
                  } else {
                    Text('').width(52)
                  }
                  Text('✎')
                    .fontSize(AppFont.Body)
                    .fontColor($r('sys.color.font_tertiary'))
                    .onClick(() => {
                      this.openWeightEdit(record)
                    })
                }
                .width('100%')
                .padding({ top: 9, bottom: 9, left: 14, right: 14 })
                .borderRadius(AppRadius.Md)
                .backgroundColor($r('sys.color.comp_background_primary'))
                .border({ width: 1, color: AppColor.Divider })
                .margin({ bottom: AppSpace.Xs })
              }, (record: WeightRecord) => record.id.toString() + '-' + record.weight.toString())
            }
          }
          .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: PAGE_SCROLL_BOTTOM })
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.reload()
      })
      // 体重 sheet 挂在此节点：根节点已挂习惯 sheet，同一节点链式多 sheet 会互相覆盖
      .bindSheet($$this.showWeightForm, this.weightFormBuilder(), {
        height: 460,
        dragBar: true,
        preferType: SheetType.BOTTOM,
        backgroundColor: AppMaterial.SheetBackground,
        blurStyle: AppMaterial.SheetBlur,
        systemMaterial: AppMaterial.Sheet
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    // 习惯表单
    .bindSheet($$this.showHabitForm, this.habitFormBuilder(), {
      height: 460,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      backgroundColor: AppMaterial.SheetBackground,
      blurStyle: AppMaterial.SheetBlur,
      systemMaterial: AppMaterial.Sheet
    })
  }

  @Builder
  weightFormBuilder() {
    Column() {
      SheetHeader({ title: this.weightFormId === 0 ? '记录体重' : '编辑体重' })

      Text('体重（kg）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '例如 65.5', text: this.weightValue })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .height(42)
        .align(Alignment.Start)
        .type(InputType.NUMBER_DECIMAL)
        .onChange((value: string) => {
          this.weightValue = value
        })

      Text('日期').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      Text(this.weightDate)
        .fontSize(AppFont.Body)
        .fontColor(AppColor.Brand)
        .width('100%')
        .height(42)
        .padding({ left: 12 })
        .borderRadius(AppRadius.Md)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onClick(() => {
          this.pickWeightDate()
        })

      SheetSubmit({
        label: '保 存',
        onSubmit: (): void => {
          this.saveWeight()
        }
      })

      if (this.weightFormId > 0) {
        SheetDelete({
          label: '删除该记录',
          onDelete: (): void => {
            this.removeWeight(this.weightFormId)
          }
        })
      }
    }
    .padding({
      left: PAGE_PAD_H,
      right: PAGE_PAD_H,
      top: SHEET_PAD_TOP,
      bottom: SHEET_PAD_BOTTOM
    })
  }

  @Builder
  habitFormBuilder() {
    Column() {
      SheetHeader({ title: this.habitFormId === 0 ? '新建习惯' : '编辑习惯' })

      Text('名称').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '例如：每天喝水 8 杯', text: this.habitName })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .height(42)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.habitName = value
        })

      Text('图标').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(HABIT_ICONS, (icon: string, index: number) => {
          Text(icon)
            .fontSize(20)
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .borderRadius(AppRadius.Md)
            .backgroundColor(this.habitIconIndex === index ? AppColor.BrandSoft : $r('sys.color.comp_background_tertiary'))
            .border({ width: 2, color: this.habitIconIndex === index ? AppColor.Brand : AppColor.Divider })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.habitIconIndex = index
            })
        }, (icon: string) => icon + this.habitIconIndex.toString())
      }
      .width('100%')

      SheetSubmit({
        label: this.savingLabel(),
        onSubmit: (): void => {
          this.saveHabit()
        }
      })

      if (this.habitFormId > 0) {
        SheetDelete({
          label: '删除该习惯',
          onDelete: (): void => {
            this.removeHabit(this.habitFormId)
          }
        })
      }
    }
    .padding({
      left: PAGE_PAD_H,
      right: PAGE_PAD_H,
      top: SHEET_PAD_TOP,
      bottom: SHEET_PAD_BOTTOM
    })
  }

  private savingLabel(): string {
    return '保 存'
  }
}

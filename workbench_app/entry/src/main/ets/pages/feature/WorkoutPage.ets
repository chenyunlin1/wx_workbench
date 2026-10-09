import { Fmt, Options, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { Workout, WorkoutDay, WorkoutListResult, WorkoutPayload, WorkoutStats } from '../../model/Models'
import { EmptyView, MiniBar, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SectionTitle, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StatTile, TechCard } from '../../components/Ui'

class TypeAgg {
  count: number = 0;
  duration: number = 0;
  calories: number = 0;
}

@ComponentV2
export struct WorkoutPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local stats: WorkoutStats | null = null;
  @Local workouts: Workout[] = [];
  @Local total: number = 0;
  @Local daysIndex: number = 0;
  @Local refreshing: boolean = false;
  @Local loading: boolean = true;
  @Local showForm: boolean = false;
  @Local formId: number = 0;
  @Local formTypeIndex: number = 0;
  @Local formTitle: string = '';
  @Local formDuration: string = '';
  @Local formCalories: string = '';
  @Local formDistance: string = '';
  @Local formIntensityIndex: number = 1;
  @Local formDate: string = Fmt.today();
  @Local formNote: string = '';
  @Local saving: boolean = false;

  aboutToAppear(): void {
    this.reload()
  }

  private days(): number {
    return [7, 14, 30][this.daysIndex]
  }

  private reload(): void {
    Api.workoutStats(this.days()).then((data: WorkoutStats) => {
      this.stats = data
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载统计失败')
    })
    const query: Record<string, string> = {
      'page': '1',
      'pageSize': '50',
      'days': this.days().toString()
    }
    Api.listWorkouts(query).then((result: WorkoutListResult) => {
      this.workouts = result.items
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载记录失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private maxDailyDuration(): number {
    if (this.stats === null) {
      return 1
    }
    let max = 1
    for (const d of this.stats.daily) {
      if (d.duration > max) {
        max = d.duration
      }
    }
    return max
  }

  private typeAgg(type: string): TypeAgg {
    let count = 0
    let duration = 0
    let calories = 0
    if (this.stats !== null) {
      for (const item of this.stats.byType) {
        if (item.type === type) {
          count = item.sessions
          duration = item.duration
          calories = item.calories
        }
      }
    }
    const agg: TypeAgg = { count: count, duration: duration, calories: calories }
    return agg
  }

  private openCreate(): void {
    this.formId = 0
    this.formTypeIndex = 0
    this.formTitle = ''
    this.formDuration = ''
    this.formCalories = ''
    this.formDistance = ''
    this.formIntensityIndex = 1
    this.formDate = Fmt.today()
    this.formNote = ''
    this.showForm = true
  }

  private openEdit(item: Workout): void {
    this.formId = item.id
    this.formTypeIndex = Math.max(0, Options.WORKOUT_TYPES.indexOf(item.type))
    this.formTitle = item.title === null || item.title === undefined ? '' : item.title
    this.formDuration = item.duration.toString()
    this.formCalories = item.calories === null || item.calories === undefined ? '' : item.calories.toString()
    this.formDistance = item.distance === null || item.distance === undefined ? '' : item.distance.toString()
    this.formIntensityIndex = item.intensity === 'low' ? 0 : item.intensity === 'high' ? 2 : 1
    this.formDate = Fmt.dateOnly(item.workoutDate)
    this.formNote = item.note === null || item.note === undefined ? '' : item.note
    this.showForm = true
  }

  private pickDate(): void {
    const base = this.formDate.length === 10 ? Fmt.parse(this.formDate + ' 09:00:00') : new Date()
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2035, 11, 31),
      selected: base,
      onDateAccept: (value: Date) => {
        this.formDate = Fmt.date(value)
      }
    })
  }

  private saveForm(): void {
    const duration = parseInt(this.formDuration.length === 0 ? '0' : this.formDuration)
    if (isNaN(duration) || duration <= 0) {
      toast('请输入有效时长（分钟）')
      return
    }
    const payload: WorkoutPayload = {
      type: Options.WORKOUT_TYPES[this.formTypeIndex],
      duration: duration,
      intensity: Options.WORKOUT_INTENSITY[this.formIntensityIndex],
      workoutDate: this.formDate
    }
    if (this.formTitle.trim().length > 0) {
      payload.title = this.formTitle.trim()
    }
    const calories = parseFloat(this.formCalories)
    if (!isNaN(calories) && calories > 0) {
      payload.calories = Math.round(calories)
    }
    const distance = parseFloat(this.formDistance)
    if (!isNaN(distance) && distance > 0) {
      payload.distance = distance
    }
    if (this.formNote.trim().length > 0) {
      payload.note = this.formNote.trim()
    }
    this.saving = true
    const call = this.formId === 0
      ? Api.createWorkout(payload)
      : Api.updateWorkout(this.formId, payload)
    call.then(() => {
      toast('已保存')
      this.showForm = false
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    }).finally(() => {
      this.saving = false
    })
  }

  private removeWorkout(id: number): void {
    Api.deleteWorkout(id).then(() => {
      toast('已删除')
      this.showForm = false
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
            PageHeader({ navStack: this.nav, title: '减脂健身', actionLabel: '＋ 训练', onAction: (): void => {
              this.openCreate()
            } })

            Row() {
              OptionChips({
                options: ['近 7 天', '近 14 天', '近 30 天'],
                selected: this.daysIndex,
                onSelect: (index: number) => {
                  this.daysIndex = index
                  this.reload()
                }
              })
            }
            .width('100%')
            .padding({ bottom: AppSpace.Xs })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else {
              // 概览
              Row({ space: 10 }) {
                StatTile({ weighted: true,
                  icon: '🏃',
                  value: this.stats === null ? '-' : this.stats.sessions.toString(),
                  label: '训练次数',
                  accent: AppColor.Brand
                })
                StatTile({ weighted: true,
                  icon: '⏱',
                  value: this.stats === null ? '-' : this.stats.duration + ' 分',
                  label: '总时长',
                  accent: AppColor.BrandDark
                })
              }
              .width('100%')
              Row({ space: 10 }) {
                StatTile({ weighted: true,
                  icon: '🔥',
                  value: this.stats === null ? '-' : this.stats.calories.toString(),
                  label: '总消耗(kcal)',
                  accent: Theme.DANGER
                })
                StatTile({ weighted: true,
                  icon: '📅',
                  value: this.stats === null ? '-' : this.stats.streakDays + ' 天',
                  label: '连续训练',
                  accent: AppColor.Brand
                })
              }
              .width('100%')
              .margin({ top: 10 })

              // 每日柱状图
              Column() {
              TechCard() {
                Column({ space: 10 }) {
                  SectionTitle({ title: '每日训练时长（分钟）' })
                  Row({ space: AppSpace.Xxs }) {
                    ForEach(this.stats === null ? [] : this.stats.daily, (day: WorkoutDay) => {
                      Column() {
                        Column()
                          .width('100%')
                          .height(day.duration > 0 ? 12 + (day.duration / this.maxDailyDuration()) * 48 : 3)
                          .borderRadius(4)
                          .backgroundColor(day.duration > 0 ? AppColor.Brand : $r('sys.color.comp_background_tertiary'))
                      }
                      .height(64)
                      .justifyContent(FlexAlign.End)
                      .layoutWeight(1)
                    }, (day: WorkoutDay) => day.date)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Bottom)
                }
              }
              }
                .width('100%')
              .margin({ top: 14 })

              // 类型分布
              Column() {
              TechCard() {
                Column({ space: 10 }) {
                  SectionTitle({ title: '类型分布' })
                  ForEach(Options.WORKOUT_TYPES, (type: string) => {
                    this.typeRow(type)
                  }, (type: string) => type)
                }
              }
              }
                .width('100%')
              .margin({ top: AppSpace.Sm })

              // 记录列表
              Column() {
                SectionTitle({ title: '训练记录（' + this.total + '）' })
              }
              .width('100%')
              .margin({ top: AppSpace.Md })

              if (this.workouts.length === 0) {
                EmptyView({ icon: '🏋️', text: '该时间段还没有训练记录' })
              } else {
                ForEach(this.workouts, (item: Workout) => {
                  Column() {
                  TechCard() {
                    Row({ space: AppSpace.Sm }) {
                      Text(Options.workoutEmoji(item.type))
                        .fontSize(24)
                      Column({ space: 4 }) {
                        Text(item.title === null || item.title === undefined || item.title.length === 0
                          ? Options.workoutTypeName(item.type) : item.title)
                          .fontSize(AppFont.BodyL)
                          .fontWeight(FontWeight.Bold)
                          .fontColor($r('sys.color.font_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Row({ space: AppSpace.Xs }) {
                          Text(Fmt.dateOnly(item.workoutDate))
                            .fontSize(11)
                            .fontColor($r('sys.color.font_secondary'))
                          Text('⏱ ' + item.duration + '分')
                            .fontSize(11)
                            .fontColor(AppColor.Brand)
                          if (item.calories !== null && item.calories !== undefined) {
                            Text('🔥 ' + item.calories)
                              .fontSize(11)
                              .fontColor(Theme.DANGER)
                          }
                          if (item.distance !== null && item.distance !== undefined) {
                            Text('📏 ' + item.distance + 'km')
                              .fontSize(11)
                              .fontColor(AppColor.Brand)
                          }
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      Column({ space: 6 }) {
                        Text(Options.intensityLabel(item.intensity))
                          .fontSize(10)
                          .fontColor($r('sys.color.font_secondary'))
                          .padding({ left: AppSpace.Xs, right: AppSpace.Xs, top: 3, bottom: 3 })
                          .borderRadius(AppRadius.Pill)
                          .border({ width: 1, color: AppColor.Divider })
                        Text('✎')
                          .fontSize(AppFont.BodyL)
                          .fontColor($r('sys.color.font_tertiary'))
                          .onClick(() => {
                            this.openEdit(item)
                          })
                      }
                    }
                    .width('100%')
                  }
                  }
                    .width('100%')
                  .margin({ bottom: AppSpace.Xs })
                }, (item: Workout) => item.id.toString() + '-' + item.updatedAt)
              }
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 680,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      backgroundColor: AppMaterial.SheetBackground,
      blurStyle: AppMaterial.SheetBlur,
      systemMaterial: AppMaterial.Sheet
    })
  }

  @Builder
  typeRow(type: string) {
    Row({ space: 10 }) {
      Text(Options.workoutTypeLabel(type))
        .fontSize(AppFont.Caption)
        .fontColor($r('sys.color.font_primary'))
        .width(64)
      Text(this.typeAgg(type).count + '次')
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .width(40)
      Text(this.typeAgg(type).duration + '分')
        .fontSize(11)
        .fontColor(AppColor.Brand)
        .width(48)
      Column() {
        MiniBar({ ratio: this.stats === null || this.stats.duration === 0
          ? 0 : this.typeAgg(type).duration / this.stats.duration })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  formBuilder() {
    Scroll() {
      Column() {
        SheetHeader({ title: this.formId === 0 ? '记录训练' : '编辑训练' })

        Text('类型').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: Options.WORKOUT_TYPES,
          labels: Options.WORKOUT_TYPES.map((type: string): string => Options.workoutTypeLabel(type)),
          selected: this.formTypeIndex,
          onSelect: (index: number) => {
            this.formTypeIndex = index
          }
        })

        Row({ space: 10 }) {
          Column() {
            Text('时长（分钟）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ bottom: 6 })
            TextInput({ placeholder: '45', text: this.formDuration })
              .placeholderColor($r('sys.color.font_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .fontSize(AppFont.Body)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(AppRadius.Md)
              .height(42)
              .align(Alignment.Start)
              .type(InputType.Number)
              .onChange((value: string) => {
                this.formDuration = value
              })
          }
          .layoutWeight(1)
          Column() {
            Text('消耗（kcal，可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ bottom: 6 })
            TextInput({ placeholder: '300', text: this.formCalories })
              .placeholderColor($r('sys.color.font_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .fontSize(AppFont.Body)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(AppRadius.Md)
              .height(42)
              .align(Alignment.Start)
              .type(InputType.Number)
              .onChange((value: string) => {
                this.formCalories = value
              })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: AppSpace.Xxs })

        if (this.showDistance()) {
          Text('距离（km，可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
          TextInput({ placeholder: '5.0', text: this.formDistance })
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .fontSize(AppFont.Body)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(42)
            .align(Alignment.Start)
            .type(InputType.NUMBER_DECIMAL)
            .onChange((value: string) => {
              this.formDistance = value
            })
        }

        Text('训练名称（可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '例如：晨跑 5 公里', text: this.formTitle })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTitle = value
          })

        Text('强度').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        OptionChips({
          options: ['低强度', '中等强度', '高强度'],
          selected: this.formIntensityIndex,
          onSelect: (index: number) => {
            this.formIntensityIndex = index
          }
        })

        Text('训练日期').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        Text(this.formDate)
          .fontSize(AppFont.Body)
          .fontColor(AppColor.Brand)
          .width('100%')
          .height(42)
          .padding({ left: 12 })
          .borderRadius(AppRadius.Md)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .onClick(() => {
            this.pickDate()
          })

        Text('备注（可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '身体感受、配速等', text: this.formNote })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(40)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formNote = value
          })

        SheetSubmit({
          label: this.saving ? '保存中…' : '保 存',
          busy: this.saving,
          onSubmit: (): void => {
            this.saveForm()
          }
        })

        if (this.formId > 0) {
          SheetDelete({
            label: '删除该训练',
            onDelete: (): void => {
              this.removeWorkout(this.formId)
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
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .height('100%')
  }

  private showDistance(): boolean {
    const type = Options.WORKOUT_TYPES[this.formTypeIndex]
    return type === 'running' || type === 'cycling' || type === 'swimming' || type === 'walking'
  }
}

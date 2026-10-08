import { Fmt, Options, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { Workout, WorkoutDay, WorkoutPayload, WorkoutStats } from '../../model/Models'
import { EmptyView, MiniBar, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SectionTitle, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StatTile, TechCard } from '../../components/Ui'

interface TypeAgg {
  count: number
  duration: number
  calories: number
}

@Component
export struct WorkoutPage {
  @Consume('nav') nav: NavPathStack
  @State stats: WorkoutStats | null = null
  @State workouts: Workout[] = []
  @State total: number = 0
  @State daysIndex: number = 0
  @State refreshing: boolean = false
  @State loading: boolean = true
  @State showForm: boolean = false
  @State formId: number = 0
  @State formTypeIndex: number = 0
  @State formTitle: string = ''
  @State formDuration: string = ''
  @State formCalories: string = ''
  @State formDistance: string = ''
  @State formIntensityIndex: number = 1
  @State formDate: string = Fmt.today()
  @State formNote: string = ''
  @State saving: boolean = false

  aboutToAppear(): void {
    this.reload()
  }

  days(): number {
    return [7, 14, 30][this.daysIndex]
  }

  reload(): void {
    Api.workoutStats(this.days()).then((data) => {
      this.stats = data
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载统计失败')
    })
    const query: Record<string, string> = {
      'page': '1',
      'pageSize': '50',
      'days': this.days().toString()
    }
    Api.listWorkouts(query).then((result) => {
      this.workouts = result.items
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载记录失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  maxDailyDuration(): number {
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

  typeAgg(type: string): TypeAgg {
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

  openCreate(): void {
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

  openEdit(item: Workout): void {
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

  pickDate(): void {
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

  saveForm(): void {
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

  removeWorkout(id: number): void {
    Api.deleteWorkout(id).then(() => {
      toast('已删除')
      this.showForm = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  build() {
    NavDestination() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({ title: '减脂健身', actionLabel: '＋ 训练', onAction: (): void => {
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
            .padding({ bottom: 8 })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else {
              // 概览
              Row({ space: 10 }) {
                StatTile({ weighted: true,
                  icon: '🏃',
                  value: this.stats === null ? '-' : this.stats.sessions.toString(),
                  label: '训练次数',
                  accent: Theme.CYAN
                })
                StatTile({ weighted: true,
                  icon: '⏱',
                  value: this.stats === null ? '-' : this.stats.duration + ' 分',
                  label: '总时长',
                  accent: Theme.VIOLET
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
                  accent: Theme.MINT
                })
              }
              .width('100%')
              .margin({ top: 10 })

              // 每日柱状图
              Column() {
              TechCard() {
                Column({ space: 10 }) {
                  SectionTitle({ title: '每日训练时长（分钟）' })
                  Row({ space: 4 }) {
                    ForEach(this.stats === null ? [] : this.stats.daily, (day: WorkoutDay) => {
                      Column() {
                        Column()
                          .width('100%')
                          .height(day.duration > 0 ? 12 + (day.duration / this.maxDailyDuration()) * 48 : 3)
                          .borderRadius(4)
                          .linearGradient({
                            angle: 180,
                            colors: day.duration > 0 ? Theme.MINT_COLORS : Theme.CARD_COLORS
                          })
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
              .margin({ top: 12 })

              // 记录列表
              Column() {
                SectionTitle({ title: '训练记录（' + this.total + '）' })
              }
              .width('100%')
              .margin({ top: 16 })

              if (this.workouts.length === 0) {
                EmptyView({ icon: '🏋️', text: '该时间段还没有训练记录' })
              } else {
                ForEach(this.workouts, (item: Workout) => {
                  Column() {
                  TechCard() {
                    Row({ space: 12 }) {
                      Text(Options.workoutEmoji(item.type))
                        .fontSize(24)
                      Column({ space: 4 }) {
                        Text(item.title === null || item.title === undefined || item.title.length === 0
                          ? Options.workoutTypeName(item.type) : item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Theme.TEXT)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Row({ space: 8 }) {
                          Text(Fmt.dateOnly(item.workoutDate))
                            .fontSize(11)
                            .fontColor(Theme.TEXT_SUB)
                          Text('⏱ ' + item.duration + '分')
                            .fontSize(11)
                            .fontColor(Theme.CYAN)
                          if (item.calories !== null && item.calories !== undefined) {
                            Text('🔥 ' + item.calories)
                              .fontSize(11)
                              .fontColor(Theme.DANGER)
                          }
                          if (item.distance !== null && item.distance !== undefined) {
                            Text('📏 ' + item.distance + 'km')
                              .fontSize(11)
                              .fontColor(Theme.MINT)
                          }
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      Column({ space: 6 }) {
                        Text(Options.intensityLabel(item.intensity))
                          .fontSize(10)
                          .fontColor(Theme.TEXT_SUB)
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .borderRadius(999)
                          .border({ width: 1, color: Theme.BORDER_GLOW })
                        Text('✎')
                          .fontSize(13)
                          .fontColor(Theme.TEXT_FAINT)
                          .onClick(() => {
                            this.openEdit(item)
                          })
                      }
                    }
                    .width('100%')
                  }
                  }
                    .width('100%')
                  .margin({ bottom: 10 })
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
    .backgroundColor(Theme.BG)
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 680,
      dragBar: true,
      backgroundColor: Theme.CARD_SOLID
    })
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }

  @Builder
  typeRow(type: string) {
    Row({ space: 10 }) {
      Text(Options.workoutTypeLabel(type))
        .fontSize(12)
        .fontColor(Theme.TEXT)
        .width(64)
      Text(this.typeAgg(type).count + '次')
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
        .width(40)
      Text(this.typeAgg(type).duration + '分')
        .fontSize(11)
        .fontColor(Theme.CYAN)
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

        Text('类型').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(Options.WORKOUT_TYPES, (type: string, index: number) => {
            Text(Options.workoutTypeLabel(type))
              .fontSize(12)
              .fontColor(this.formTypeIndex === index ? '#FFFFFF' : Theme.TEXT_SUB)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(10)
              .backgroundColor(this.formTypeIndex === index ? Theme.PRIMARY : Theme.INPUT_BG)
              .border({ width: 1, color: this.formTypeIndex === index ? Theme.PRIMARY : Theme.BORDER })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.formTypeIndex = index
              })
          }, (type: string) => type + this.formTypeIndex.toString())
        }
        .width('100%')

        Row({ space: 10 }) {
          Column() {
            Text('时长（分钟）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ bottom: 6 })
            TextInput({ placeholder: '45', text: this.formDuration })
              .fontColor(Theme.TEXT)
              .fontSize(14)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(10)
              .border({ width: 1, color: Theme.BORDER })
              .height(42)
              .align(Alignment.Start)
              .type(InputType.Number)
              .onChange((value: string) => {
                this.formDuration = value
              })
          }
          .layoutWeight(1)
          Column() {
            Text('消耗（kcal，可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ bottom: 6 })
            TextInput({ placeholder: '300', text: this.formCalories })
              .fontColor(Theme.TEXT)
              .fontSize(14)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(10)
              .border({ width: 1, color: Theme.BORDER })
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
        .margin({ top: 4 })

        if (this.showDistance()) {
          Text('距离（km，可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
          TextInput({ placeholder: '5.0', text: this.formDistance })
            .fontColor(Theme.TEXT)
            .fontSize(14)
            .backgroundColor(Theme.INPUT_BG)
            .borderRadius(10)
            .border({ width: 1, color: Theme.BORDER })
            .height(42)
            .align(Alignment.Start)
            .type(InputType.NUMBER_DECIMAL)
            .onChange((value: string) => {
              this.formDistance = value
            })
        }

        Text('训练名称（可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '例如：晨跑 5 公里', text: this.formTitle })
          .fontColor(Theme.TEXT)
          .fontSize(14)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTitle = value
          })

        Text('强度').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        OptionChips({
          options: ['低强度', '中等强度', '高强度'],
          selected: this.formIntensityIndex,
          onSelect: (index: number) => {
            this.formIntensityIndex = index
          }
        })

        Text('训练日期').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        Text(this.formDate)
          .fontSize(14)
          .fontColor(Theme.CYAN)
          .width('100%')
          .height(42)
          .padding({ left: 12 })
          .borderRadius(10)
          .backgroundColor(Theme.INPUT_BG)
          .border({ width: 1, color: Theme.BORDER })
          .onClick(() => {
            this.pickDate()
          })

        Text('备注（可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '身体感受、配速等', text: this.formNote })
          .fontColor(Theme.TEXT)
          .fontSize(13)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
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

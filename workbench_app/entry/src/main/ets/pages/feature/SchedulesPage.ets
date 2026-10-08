import { Fmt, Options, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { Schedule, SchedulePayload } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

@Component
export struct SchedulesPage {
  @Consume('nav') nav: NavPathStack
  @State schedules: Schedule[] = []
  @State filterIndex: number = 0
  @State refreshing: boolean = false
  @State loading: boolean = true
  @State showForm: boolean = false
  @State formId: number = 0
  @State formTitle: string = ''
  @State formDesc: string = ''
  @State formStart: string = Fmt.dateTime(new Date())
  @State formEnd: string = ''
  @State formCategoryIndex: number = 0
  @State formPriorityIndex: number = 1
  @State formRemind: boolean = false
  @State formRemindBeforeIndex: number = 1
  @State saving: boolean = false

  aboutToAppear(): void {
    this.reload()
  }

  reload(): void {
    Api.listSchedules().then((list) => {
      this.schedules = list.sort((a: Schedule, b: Schedule) => a.startTime.localeCompare(b.startTime))
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  filtered(): Schedule[] {
    const today = Fmt.today()
    if (this.filterIndex === 0) {
      return this.schedules.filter((s: Schedule) => Fmt.dateOnly(s.startTime) === today)
    }
    if (this.filterIndex === 1) {
      return this.schedules.filter((s: Schedule) => !s.completed)
    }
    return this.schedules
  }

  toggleComplete(item: Schedule): void {
    Api.toggleScheduleCompleted(item.id, !item.completed).then(() => {
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '操作失败')
    })
  }

  openCreate(): void {
    this.formId = 0
    this.formTitle = ''
    this.formDesc = ''
    this.formStart = Fmt.dateTime(new Date())
    this.formEnd = ''
    this.formCategoryIndex = 0
    this.formPriorityIndex = 1
    this.formRemind = false
    this.formRemindBeforeIndex = 1
    this.showForm = true
  }

  openEdit(item: Schedule): void {
    this.formId = item.id
    this.formTitle = item.title
    this.formDesc = item.description === null || item.description === undefined ? '' : item.description
    this.formStart = item.startTime
    this.formEnd = item.endTime === null || item.endTime === undefined ? '' : item.endTime
    this.formCategoryIndex = Math.max(0, Options.SCHEDULE_CATEGORIES.indexOf(item.category))
    this.formPriorityIndex = item.priority === 'high' ? 0 : item.priority === 'low' ? 2 : 1
    this.formRemind = item.isRemind
    const minutes = item.remindBefore === null || item.remindBefore === undefined ? 10 : item.remindBefore
    this.formRemindBeforeIndex = minutes <= 5 ? 0 : minutes <= 15 ? 1 : minutes <= 30 ? 2 : 3
    this.showForm = true
  }

  pickDate(current: string, isEnd: boolean): void {
    const base = current.length >= 10
      ? Fmt.parse(current.length > 10 ? current : current + ' 09:00:00')
      : new Date()
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2035, 11, 31),
      selected: base,
      onDateAccept: (value: Date) => {
        this.pickTime(value, current, isEnd)
      }
    })
  }

  pickTime(date: Date, current: string, isEnd: boolean): void {
    const fallback = current.length >= 16 ? Fmt.parse(current) : new Date()
    TimePickerDialog.show({
      selected: fallback,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const d = new Date(date.getFullYear(), date.getMonth(), date.getDate(), value.hour, value.minute)
        const formatted = Fmt.dateTime(d)
        if (isEnd) {
          this.formEnd = formatted
        } else {
          this.formStart = formatted
        }
      }
    })
  }

  saveForm(): void {
    if (this.formTitle.trim().length === 0) {
      toast('请输入日程标题')
      return
    }
    const payload: SchedulePayload = {
      title: this.formTitle.trim(),
      startTime: this.formStart,
      category: Options.SCHEDULE_CATEGORIES[this.formCategoryIndex],
      priority: Options.PRIORITIES[this.formPriorityIndex],
      isRemind: this.formRemind
    }
    if (this.formDesc.trim().length > 0) {
      payload.description = this.formDesc.trim()
    }
    if (this.formEnd.length > 0) {
      payload.endTime = this.formEnd
    }
    if (this.formRemind) {
      payload.remindBefore = [5, 10, 30, 60][this.formRemindBeforeIndex]
    }
    this.saving = true
    const call = this.formId === 0
      ? Api.createSchedule(payload)
      : Api.updateSchedule(this.formId, payload)
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

  removeSchedule(id: number): void {
    Api.deleteSchedule(id).then(() => {
      toast('已删除')
      this.showForm = false
      this.reload()
      Session.bumpDataVersion()
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
            PageHeader({ title: '日程管理', actionLabel: '＋ 新建', onAction: (): void => {
              this.openCreate()
            } })
            Row() {
              OptionChips({
                options: ['今天', '未完成', '全部'],
                selected: this.filterIndex,
                onSelect: (index: number) => {
                  this.filterIndex = index
                }
              })
            }
            .width('100%')
            .padding({ bottom: 8 })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.filtered().length === 0) {
              EmptyView({ icon: '📅', text: '暂无日程' })
            } else {
              List() {
                ForEach(this.filtered(), (item: Schedule) => {
                  ListItem() {
                    Column() {
                    TechCard() {
                      Row({ space: 12 }) {
                        // 完成圆点
                        Text(item.completed ? '✔' : '')
                          .fontSize(14)
                          .fontColor('#FFFFFF')
                          .width(24)
                          .height(24)
                          .textAlign(TextAlign.Center)
                          .borderRadius(12)
                          .backgroundColor(item.completed ? Theme.MINT : 'transparent')
                          .border({ width: 2, color: item.completed ? Theme.MINT : Theme.BORDER_GLOW })
                          .onClick(() => {
                            this.toggleComplete(item)
                          })

                        Column({ space: 3 }) {
                          Text(item.title)
                            .fontSize(15)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(item.completed ? Theme.TEXT_FAINT : Theme.TEXT)
                            .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          Row({ space: 8 }) {
                            Text(Fmt.timeOnly(item.startTime) + (item.endTime !== null && item.endTime !== undefined
                              ? ' - ' + Fmt.timeOnly(item.endTime) : ''))
                              .fontSize(11)
                              .fontColor(Theme.CYAN)
                            Text('· ' + item.category)
                              .fontSize(11)
                              .fontColor(Theme.TEXT_SUB)
                            Text('· ' + Theme.priorityLabel(item.priority) + '优先')
                              .fontSize(11)
                              .fontColor(Theme.priorityColor(item.priority))
                            if (item.isRemind) {
                              Text('· ⏰')
                                .fontSize(11)
                                .fontColor(Theme.WARN)
                            }
                          }
                          if (item.description !== null && item.description !== undefined && item.description.length > 0) {
                            Text(item.description)
                              .fontSize(11)
                              .fontColor(Theme.TEXT_FAINT)
                              .maxLines(2)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)

                        Text('✎')
                          .fontSize(16)
                          .fontColor(Theme.TEXT_FAINT)
                          .onClick(() => {
                            this.openEdit(item)
                          })
                      }
                      .width('100%')
                    }
                    }
                      .width('100%')
                    .margin({ bottom: 10 })
                  }
                }, (item: Schedule) => item.id.toString() + '-' + item.completed.toString())
              }
              .width('100%')
              .layoutWeight(1)
              .padding({ bottom: 44 })
              .scrollBar(BarState.Off)
            }
          }
          .width('100%')
          .height('100%')
          .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: PAGE_SCROLL_BOTTOM })
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
      height: 640,
      dragBar: true,
      backgroundColor: Theme.CARD_SOLID
    })
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }

  @Builder
  formBuilder() {
    Scroll() {
      Column() {
        SheetHeader({ title: this.formId === 0 ? '新建日程' : '编辑日程' })

        Text('标题').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '日程标题', text: this.formTitle })
          .placeholderColor(Theme.TEXT_FAINT)
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

        Text('描述（可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '补充说明', text: this.formDesc })
          .placeholderColor(Theme.TEXT_FAINT)
          .fontColor(Theme.TEXT)
          .fontSize(13)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(40)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formDesc = value
          })

        Text('开始时间').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        Text(this.formStart)
          .fontSize(14)
          .fontColor(Theme.CYAN)
          .width('100%')
          .height(42)
          .padding({ left: 12 })
          .borderRadius(10)
          .backgroundColor(Theme.INPUT_BG)
          .border({ width: 1, color: Theme.BORDER })
          .onClick(() => {
            this.pickDate(this.formStart, false)
          })

        Text('结束时间（可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        Text(this.formEnd.length > 0 ? this.formEnd : '点击选择')
          .fontSize(14)
          .fontColor(this.formEnd.length > 0 ? Theme.CYAN : Theme.TEXT_FAINT)
          .width('100%')
          .height(42)
          .padding({ left: 12 })
          .borderRadius(10)
          .backgroundColor(Theme.INPUT_BG)
          .border({ width: 1, color: Theme.BORDER })
          .onClick(() => {
            this.pickDate(this.formEnd.length > 0 ? this.formEnd : this.formStart, true)
          })

        Text('分类').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        OptionChips({
          options: Options.SCHEDULE_CATEGORIES,
          selected: this.formCategoryIndex,
          onSelect: (index: number) => {
            this.formCategoryIndex = index
          }
        })

        Text('优先级').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        OptionChips({
          options: ['高', '中', '低'],
          selected: this.formPriorityIndex,
          onSelect: (index: number) => {
            this.formPriorityIndex = index
          }
        })

        Row({ space: 10 }) {
          Text('开启提醒')
            .fontSize(13)
            .fontColor(Theme.TEXT)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.formRemind })
            .selectedColor(Theme.MINT)
            .onChange((isOn: boolean) => {
              this.formRemind = isOn
            })
        }
        .width('100%')
        .margin({ top: 14 })

        if (this.formRemind) {
          Text('提前提醒').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 10, bottom: 6 })
          OptionChips({
            options: ['5 分钟', '10 分钟', '30 分钟', '1 小时'],
            selected: this.formRemindBeforeIndex,
            onSelect: (index: number) => {
              this.formRemindBeforeIndex = index
            }
          })
        }

        SheetSubmit({
          label: this.saving ? '保存中…' : '保 存',
          busy: this.saving,
          onSubmit: (): void => {
            this.saveForm()
          }
        })

        if (this.formId > 0) {
          SheetDelete({
            label: '删除该日程',
            onDelete: (): void => {
              this.removeSchedule(this.formId)
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
}

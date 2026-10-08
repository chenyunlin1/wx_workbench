import { toast, Options } from '../../common/AppKit'
import { Api, LearningPayload } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { LearningTask } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, SectionTitle, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StatTile, TechCard } from '../../components/Ui'

function statusColor(status: string): string {
  if (status === 'doing') {
    return Theme.WARN
  }
  if (status === 'done') {
    return Theme.MINT
  }
  return '#93A7C8'
}

@Component
export struct LearningTab {
  @Consume('topInset') topInset: number
  @Consume('nav') nav: NavPathStack
  @StorageLink('dataVersion') @Watch('reload') version: number = 0
  @State tasks: LearningTask[] = []
  @State refreshing: boolean = false
  @State statusIndex: number = 0
  @State noteTotal: number = -1
  @State noteLearned: number = -1
  @State showForm: boolean = false
  @State formId: number = 0
  @State formTitle: string = ''
  @State formDuration: string = ''
  @State formStatusIndex: number = 0
  @State saving: boolean = false

  aboutToAppear(): void {
    this.reload()
  }

  reload(): void {
    Api.listLearning().then((list) => {
      this.tasks = list
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.refreshing = false
    })
    this.loadPracticeCount()
  }

  /** 练习题库规模：只取「全部」与「已学」，待学由两者相减，避免第三次请求出现不一致的中间态 */
  loadPracticeCount(): void {
    Api.practiceCount('all').then((count) => {
      this.noteTotal = count
    }).catch(() => {
      this.noteTotal = 0
    })
    Api.practiceCount('learned').then((count) => {
      this.noteLearned = count
    }).catch(() => {
      this.noteLearned = 0
    })
  }

  noteCountText(value: number): string {
    return value < 0 ? '…' : value.toString()
  }

  notePendingCount(): number {
    if (this.noteTotal < 0 || this.noteLearned < 0) {
      return -1
    }
    return this.noteTotal - this.noteLearned
  }

  startPractice(): void {
    if (this.noteTotal === 0) {
      toast('题库还没有笔记，先去「备忘」添加知识条目')
      return
    }
    this.nav.pushPathByName('practice', null)
  }

  filtered(): LearningTask[] {
    if (this.statusIndex === 0) {
      return this.tasks
    }
    const target = ['all', 'todo', 'doing', 'done'][this.statusIndex]
    return this.tasks.filter((t: LearningTask) => t.status === target)
  }

  totalMinutes(): number {
    let sum = 0
    for (const t of this.tasks) {
      sum += t.duration
    }
    return sum
  }

  doneCount(): number {
    return this.tasks.filter((t: LearningTask) => t.status === 'done').length
  }

  openCreate(): void {
    this.formId = 0
    this.formTitle = ''
    this.formDuration = ''
    this.formStatusIndex = 1
    this.showForm = true
  }

  openEdit(task: LearningTask): void {
    this.formId = task.id
    this.formTitle = task.title
    this.formDuration = task.duration.toString()
    this.formStatusIndex = task.status === 'todo' ? 1 : task.status === 'doing' ? 2 : 3
    this.showForm = true
  }

  setStatus(id: number, status: string): void {
    const task = this.tasks.find((t: LearningTask) => t.id === id)
    if (task === undefined) {
      return
    }
    Api.updateLearning(id, { title: task.title, duration: task.duration, status: status })
      .then(() => {
        this.reload()
        Session.bumpDataVersion()
      })
      .catch((err: Object) => {
        toast(err instanceof Error ? err.message : '操作失败')
      })
  }

  saveForm(): void {
    if (this.formTitle.trim().length === 0) {
      toast('请输入任务标题')
      return
    }
    const duration = parseInt(this.formDuration.length === 0 ? '0' : this.formDuration)
    if (isNaN(duration) || duration < 0) {
      toast('学习时长需为非负整数（分钟）')
      return
    }
    const status = ['todo', 'todo', 'doing', 'done'][this.formStatusIndex]
    const payload: LearningPayload = {
      title: this.formTitle.trim(),
      duration: duration,
      status: status
    }
    this.saving = true
    const call = this.formId === 0
      ? Api.createLearning(payload)
      : Api.updateLearning(this.formId, payload)
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

  removeTask(task: LearningTask): void {
    Api.deleteLearning(task.id).then(() => {
      toast('已删除')
      this.showForm = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  @Builder
  statusChip(status: string) {
    Text(Options.learningStatusLabel(status))
      .fontSize(10)
      .fontColor(statusColor(status))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(999)
      .border({ width: 1, color: statusColor(status) })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            Row() {
              Text('学习')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: 14 })

            // 知识练习：本 Tab 的主入口，答题流程在 PracticePage
            Column() {
              SectionTitle({ title: '知识练习' })
              TechCard() {
                Column({ space: 12 }) {
                  Row({ space: 10 }) {
                    StatTile({ weighted: true,
                      icon: '🗂️',
                      value: this.noteCountText(this.noteTotal),
                      label: '题库笔记',
                      accent: Theme.CYAN
                    })
                    StatTile({ weighted: true,
                      icon: '✅',
                      value: this.noteCountText(this.noteLearned),
                      label: '已学',
                      accent: Theme.MINT
                    })
                    StatTile({ weighted: true,
                      icon: '⏳',
                      value: this.noteCountText(this.notePendingCount()),
                      label: '待学',
                      accent: Theme.WARN
                    })
                  }
                  .width('100%')
                  Text('闪卡记忆与填空选择，题目由知识库自动生成')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_FAINT)
                    .width('100%')
                  Text('开始练习')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .height(46)
                    .borderRadius(12)
                    .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
                    .onClick(() => {
                      this.startPractice()
                    })
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ bottom: 18 })

            Row({ space: 10 }) {
              Column() {
                SectionTitle({ title: '学习计划' })
              }
              .layoutWeight(1)
              Text('＋ 新任务')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(11)
                .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
                .margin({ bottom: 10 })
                .onClick(() => {
                  this.openCreate()
                })
            }
            .width('100%')

            Row({ space: 10 }) {
              StatTile({ weighted: true, icon: '📋', value: this.tasks.length.toString(), label: '全部任务', accent: Theme.CYAN })
              StatTile({ weighted: true, icon: '✅', value: this.doneCount().toString(), label: '已完成', accent: Theme.MINT })
              StatTile({ weighted: true, icon: '⏱', value: this.totalMinutes().toString(), label: '总时长(分)', accent: Theme.VIOLET })
            }
            .width('100%')

            Row() {
              OptionChips({
                options: ['全部', '待开始', '进行中', '已完成'],
                selected: this.statusIndex,
                onSelect: (index: number) => {
                  this.statusIndex = index
                }
              })
            }
            .width('100%')
            .margin({ top: 12, bottom: 6 })

            if (this.filtered().length === 0) {
              EmptyView({ icon: '📖', text: '暂无学习任务，点击右上角新建' })
            } else {
              ForEach(this.filtered(), (task: LearningTask) => {
                Column() {
                TechCard() {
                  Row({ space: 10 }) {
                    Column({ space: 6 }) {
                      Text(task.title)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(task.status === 'done' ? Theme.TEXT_FAINT : Theme.TEXT)
                        .decoration({ type: task.status === 'done' ? TextDecorationType.LineThrough : TextDecorationType.None })
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Row({ space: 8 }) {
                        this.statusChip(task.status)
                        Text('⏱ ' + task.duration + ' 分钟')
                          .fontSize(11)
                          .fontColor(Theme.TEXT_SUB)
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Column({ space: 6 }) {
                      Text(task.status === 'todo' ? '开始' : task.status === 'doing' ? '完成' : '重开')
                        .fontSize(11)
                        .fontColor('#FFFFFF')
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .borderRadius(10)
                        .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
                        .onClick(() => {
                          if (task.status === 'todo') {
                            this.setStatus(task.id, 'doing')
                          } else if (task.status === 'doing') {
                            this.setStatus(task.id, 'done')
                          } else {
                            this.setStatus(task.id, 'todo')
                          }
                        })
                      Text('编辑')
                        .fontSize(11)
                        .fontColor(Theme.CYAN)
                        .onClick(() => {
                          this.openEdit(task)
                        })
                    }
                  }
                  .width('100%')
                }
                }
                  .width('100%')
                .margin({ bottom: 10 })
              }, (task: LearningTask) => task.id.toString() + '-' + task.status)
            }
          }
          .padding({ left: 16, right: 16, top: this.topInset + 12, bottom: 20 })
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
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 460,
      dragBar: true,
      backgroundColor: Theme.CARD_SOLID
    })
  }

  @Builder
  formBuilder() {
    Column() {
      SheetHeader({ title: this.formId === 0 ? '新建学习任务' : '编辑学习任务' })

      Text('标题').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '任务标题', text: this.formTitle })
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

      Text('学习时长（分钟）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '例如 60', text: this.formDuration })
        .placeholderColor(Theme.TEXT_FAINT)
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

      Text('状态').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      OptionChips({
        options: ['待开始', '进行中', '已完成'],
        selected: this.formStatusIndex,
        onSelect: (index: number) => {
          this.formStatusIndex = index
        }
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
          label: '删除该任务',
          onDelete: (): void => {
            const task = this.tasks.find((t: LearningTask) => t.id === this.formId)
            if (task !== undefined) {
              this.removeTask(task)
            }
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
}

import { toast, Options } from '../../common/AppKit'
import { Api, LearningPayload } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { WindowUtils } from '../../utils/WindowUtils'
import { Session, SessionStore } from '../../store/Session'
import { LearningTask } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, SectionTitle, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StatTile, TechCard } from '../../components/Ui'

function statusColor(status: string): ResourceColor {
  if (status === 'doing') {
    return Theme.WARN
  }
  if (status === 'done') {
    return AppColor.Brand
  }
  return $r('sys.color.font_secondary')
}

@ComponentV2
export struct LearningTab {
  @Param nav: NavPathStack = new NavPathStack();
  @Event onScrollerReady: (scroller: Scroller) => void = () => {};
  @Local session: SessionStore = Session;
  @Local tasks: LearningTask[] = [];
  @Local refreshing: boolean = false;
  @Local statusIndex: number = 0;
  @Local noteTotal: number = -1;
  @Local noteLearned: number = -1;
  @Local showForm: boolean = false;
  @Local formId: number = 0;
  @Local formTitle: string = '';
  @Local formDuration: string = '';
  @Local formStatusIndex: number = 0;
  @Local saving: boolean = false;

  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.onScrollerReady(this.scroller);
    this.reload()
  }

  @Monitor('session.dataVersion')
  onDataVersionChange(): void {
    this.reload()
  }

  private reload(): void {
    Api.listLearning().then((list: LearningTask[]) => {
      this.tasks = list
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.refreshing = false
    })
    this.loadPracticeCount()
  }

  /** 练习题库规模：只取「全部」与「已学」，待学由两者相减，避免第三次请求出现不一致的中间态 */
  private loadPracticeCount(): void {
    Api.practiceCount('all').then((count: number) => {
      this.noteTotal = count
    }).catch(() => {
      this.noteTotal = 0
    })
    Api.practiceCount('learned').then((count: number) => {
      this.noteLearned = count
    }).catch(() => {
      this.noteLearned = 0
    })
  }

  private noteCountText(value: number): string {
    return value < 0 ? '…' : value.toString()
  }

  private notePendingCount(): number {
    if (this.noteTotal < 0 || this.noteLearned < 0) {
      return -1
    }
    return this.noteTotal - this.noteLearned
  }

  private startPractice(): void {
    if (this.noteTotal === 0) {
      toast('题库还没有笔记，先去「备忘」添加知识条目')
      return
    }
    this.nav.pushPathByName('practice', null)
  }

  private filtered(): LearningTask[] {
    if (this.statusIndex === 0) {
      return this.tasks
    }
    const target = ['all', 'todo', 'doing', 'done'][this.statusIndex]
    return this.tasks.filter((t: LearningTask) => t.status === target)
  }

  private totalMinutes(): number {
    let sum = 0
    for (const t of this.tasks) {
      sum += t.duration
    }
    return sum
  }

  private doneCount(): number {
    return this.tasks.filter((t: LearningTask) => t.status === 'done').length
  }

  private openCreate(): void {
    this.formId = 0
    this.formTitle = ''
    this.formDuration = ''
    this.formStatusIndex = 1
    this.showForm = true
  }

  private openEdit(task: LearningTask): void {
    this.formId = task.id
    this.formTitle = task.title
    this.formDuration = task.duration.toString()
    this.formStatusIndex = task.status === 'todo' ? 1 : task.status === 'doing' ? 2 : 3
    this.showForm = true
  }

  private setStatus(id: number, status: string): void {
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

  private saveForm(): void {
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

  private removeTask(task: LearningTask): void {
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
      .padding({ left: AppSpace.Xs, right: AppSpace.Xs, top: 3, bottom: 3 })
      .borderRadius(AppRadius.Pill)
      .border({ width: 1, color: statusColor(status) })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll(this.scroller) {
          Column() {
            Row() {
              Text('学习')
                .fontSize(AppFont.TitleL)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: 14 })

            // 知识练习：本 Tab 的主入口，答题流程在 PracticePage
            Column() {
              SectionTitle({ title: '知识练习' })
              TechCard() {
                Column({ space: AppSpace.Sm }) {
                  Row({ space: 10 }) {
                    StatTile({ weighted: true,
                      icon: '🗂️',
                      value: this.noteCountText(this.noteTotal),
                      label: '题库笔记',
                      accent: AppColor.Brand
                    })
                    StatTile({ weighted: true,
                      icon: '✅',
                      value: this.noteCountText(this.noteLearned),
                      label: '已学',
                      accent: AppColor.Brand
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
                    .fontColor($r('sys.color.font_tertiary'))
                    .width('100%')
                  Text('开始练习')
                    .fontSize(AppFont.BodyL)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColor.OnBrand)
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .height(46)
                    .borderRadius(AppRadius.Pill)
                    .backgroundColor(AppColor.Brand)
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
                .fontSize(AppFont.Caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.OnBrand)
                .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
                .margin({ bottom: 10 })
                .onClick(() => {
                  this.openCreate()
                })
            }
            .width('100%')

            Row({ space: 10 }) {
              StatTile({ weighted: true, icon: '📋', value: this.tasks.length.toString(), label: '全部任务', accent: AppColor.Brand })
              StatTile({ weighted: true, icon: '✅', value: this.doneCount().toString(), label: '已完成', accent: AppColor.Brand })
              StatTile({ weighted: true, icon: '⏱', value: this.totalMinutes().toString(), label: '总时长(分)', accent: AppColor.BrandDark })
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
            .margin({ top: AppSpace.Sm, bottom: 6 })

            if (this.filtered().length === 0) {
              EmptyView({ icon: '📖', text: '暂无学习任务，点击右上角新建' })
            } else {
              ForEach(this.filtered(), (task: LearningTask) => {
                Column() {
                  TechCard() {
                    Row({ space: 10 }) {
                      Column({ space: 6 }) {
                        Text(task.title)
                          .fontSize(AppFont.BodyL)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(task.status === 'done' ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
                          .decoration({ type: task.status === 'done' ? TextDecorationType.LineThrough : TextDecorationType.None })
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                        Row({ space: AppSpace.Xs }) {
                          this.statusChip(task.status)
                          Text('⏱ ' + task.duration + ' 分钟')
                            .fontSize(11)
                            .fontColor($r('sys.color.font_secondary'))
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      Column({ space: 6 }) {
                        Text(task.status === 'todo' ? '开始' : task.status === 'doing' ? '完成' : '重开')
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(AppColor.OnBrand)
                          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                          .borderRadius(AppRadius.Pill)
                          .backgroundColor(AppColor.Brand)
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
                          .fontColor(AppColor.Brand)
                          .onClick(() => {
                            this.openEdit(task)
                          })
                      }
                    }
                    .width('100%')
                  }
                }
                .width('100%')
                .margin({ bottom: AppSpace.Xs })
              }, (task: LearningTask) => task.id.toString() + '-' + task.status)
            }
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
      preferType: SheetType.BOTTOM,
      backgroundColor: AppMaterial.SheetBackground,
      blurStyle: AppMaterial.SheetBlur,
      systemMaterial: AppMaterial.Sheet
    })
  }

  @Builder
  formBuilder() {
    Column() {
      SheetHeader({ title: this.formId === 0 ? '新建学习任务' : '编辑学习任务' })

      Text('标题').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '任务标题', text: this.formTitle })
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

      Text('学习时长（分钟）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '例如 60', text: this.formDuration })
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

      Text('状态').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
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

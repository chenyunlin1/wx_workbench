import { toast, confirm, Options } from '../../common/AppKit'
import { Api, LearningPayload } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { WindowUtils } from '../../utils/WindowUtils'
import { Session, SessionStore } from '../../store/Session'
import { LearningTask } from '../../model/Models'
import { FocusStudyService, FocusTask } from '../../service/FocusStudyService'
import { KnowledgeCacheService } from '../../service/KnowledgeCacheService'
import { PasswordRevealSheet } from '../../components/FocusPasswordSheet'
import { EmptyView, Chip, MiniBar, OptionChips, PAGE_PAD_H, SectionTitle, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StatTile, TechCard } from '../../components/Ui'

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
  // 专注学习
  @Local focusTasks: FocusTask[] = [];
  @Local showFocusForm: boolean = false;
  @Local focusName: string = '';
  @Local focusTarget: string = '120';
  @Local focusMin: string = '30';
  @Local focusVerify: string = '5';
  @Local focusBgLimit: string = '3';
  @Local focusDailyLimit: string = '3';
  @Local focusRewardIndex: number = 0;
  @Local focusPassword: string = '';
  @Local focusViewSec: string = '60';
  @Local focusModeIndex: number = 0;
  @Local focusRanges: string[] = ['all', 'learned', 'unlearned'];
  @Local focusRangeLabels: string[] = ['全部笔记', '已学习笔记', '未学习笔记'];
  @Local focusRangeSelected: boolean[] = [true];
  @Local focusCountIndex: number = 1;
  @Local showReveal: boolean = false;
  @Local revealPassword: string = '';
  @Local revealSeconds: number = 60;

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
    this.focusTasks = FocusStudyService.list()
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

  /* ---------------- 专注学习 ---------------- */

  private focusKey(task: FocusTask): string {
    return task.id.toString() + '-' + task.todaySec.toString() + '-' + task.completions.toString() + '-' + task.viewChances.toString()
  }

  /** 本轮进度：距下一次完成的百分比；完成次数用尽后显示满 */
  private focusCycleRatio(task: FocusTask): number {
    if (task.completions >= task.dailyLimit) {
      return 1
    }
    const targetSec = task.dailyTargetMin * 60
    if (targetSec <= 0) {
      return 0
    }
    const cycle = task.todaySec % targetSec
    const ratio = cycle / targetSec
    return ratio > 1 ? 1 : ratio
  }

  private focusProgressText(task: FocusTask): string {
    return '今日累计 ' + Math.floor(task.todaySec / 60).toString() + '/' + task.dailyTargetMin.toString() +
      ' 分 · 完成 ' + task.completions.toString() + '/' + task.dailyLimit.toString() + ' 次'
  }

  private startFocus(task: FocusTask): void {
    if (KnowledgeCacheService.load().length === 0) {
      toast('本地知识库为空，请先到「备忘」下拉刷新同步')
      return
    }
    if (FocusStudyService.rangeCount(task) === 0) {
      toast('该练习范围当前没有可用笔记')
      return
    }
    const reason = FocusStudyService.canStartReason(task)
    if (reason.length > 0) {
      toast(reason)
      return
    }
    AppStorage.setOrCreate<number>('focusTaskId', task.id)
    this.nav.pushPathByName('focusStudy', null)
  }

  private revealFor(task: FocusTask): void {
    confirm('查看密码将消耗 1 次机会（剩余 ' + task.viewChances.toString() + ' 次），确定查看吗？', (): void => {
      if (!FocusStudyService.consumeView(task.id)) {
        toast('没有可用的查看机会')
        return
      }
      this.revealPassword = task.password
      this.revealSeconds = task.viewSeconds
      this.showReveal = true
      this.reload()
    })
  }

  private removeFocusTask(task: FocusTask): void {
    confirm('删除后该任务的配置与今日进度将清除，且无法恢复。确定删除吗？', (): void => {
      FocusStudyService.remove(task.id)
      toast('已删除')
      this.reload()
    })
  }

  private openFocusForm(): void {
    this.focusName = ''
    this.focusTarget = '120'
    this.focusMin = '30'
    this.focusVerify = '5'
    this.focusBgLimit = '3'
    this.focusDailyLimit = '3'
    this.focusRewardIndex = 0
    this.focusPassword = ''
    this.focusViewSec = '60'
    this.focusModeIndex = 0
    this.focusCountIndex = 1
    const tags = KnowledgeCacheService.tagsOf(KnowledgeCacheService.load())
    this.focusRanges = ['all', 'learned', 'unlearned'].concat(tags)
    this.focusRangeLabels = ['全部笔记', '已学习笔记', '未学习笔记'].concat(tags)
    const selected: boolean[] = []
    for (let i = 0; i < this.focusRanges.length; i += 1) {
      selected.push(i === 0)
    }
    this.focusRangeSelected = selected
    this.showFocusForm = true
  }

  /** 范围多选：「全部笔记」互斥，选中即清空其它；点其它项则取消「全部」 */
  private toggleFocusRange(index: number): void {
    const next: boolean[] = []
    for (let i = 0; i < this.focusRanges.length; i += 1) {
      next.push(this.focusRangeSelected[i] === true)
    }
    if (index === 0) {
      for (let i = 0; i < next.length; i += 1) {
        next[i] = i === 0
      }
    } else {
      next[index] = !next[index]
      next[0] = false
    }
    this.focusRangeSelected = next
  }

  private saveFocusForm(): void {
    const name = this.focusName.trim()
    if (name.length === 0) {
      toast('请输入任务名称')
      return
    }
    const target = parseInt(this.focusTarget)
    if (isNaN(target) || target <= 0) {
      toast('每日目标总时长需为正整数（分钟）')
      return
    }
    const minSegment = parseInt(this.focusMin)
    if (isNaN(minSegment) || minSegment <= 0) {
      toast('单次最少时长需为正整数（分钟）')
      return
    }
    if (minSegment > target) {
      toast('单次最少时长不能大于每日目标总时长')
      return
    }
    const verify = parseInt(this.focusVerify)
    if (isNaN(verify) || verify <= 0) {
      toast('验证间隔需为正整数（分钟）')
      return
    }
    const bgLimit = parseInt(this.focusBgLimit)
    if (isNaN(bgLimit) || bgLimit < 0) {
      toast('后台次数上限需为非负整数')
      return
    }
    const dailyLimit = parseInt(this.focusDailyLimit)
    if (isNaN(dailyLimit) || dailyLimit <= 0) {
      toast('每日完成次数上限需为正整数')
      return
    }
    const viewSec = parseInt(this.focusViewSec)
    if (isNaN(viewSec) || viewSec <= 0) {
      toast('密码可看时长需为正整数（秒）')
      return
    }
    const rewardEnabled = this.focusRewardIndex === 1
    const password = this.focusPassword.trim()
    if (rewardEnabled && password.length === 0) {
      toast('请设置任务密码')
      return
    }
    const ranges: string[] = []
    for (let i = 0; i < this.focusRanges.length; i += 1) {
      if (this.focusRangeSelected[i] === true) {
        ranges.push(this.focusRanges[i])
      }
    }
    if (ranges.length === 0) {
      toast('请至少选择一个练习范围')
      return
    }
    confirm('创建后所有配置（含密码）不可修改，只能删除重建。确定创建吗？', (): void => {
      FocusStudyService.create({
        name: name,
        dailyTargetMin: target,
        minSegmentMin: minSegment,
        verifyIntervalMin: verify,
        bgLimit: bgLimit,
        dailyLimit: dailyLimit,
        practiceMode: this.focusModeIndex === 0 ? 'flashcard' : 'fillblank',
        practiceRange: ranges.join(','),
        practiceCount: [5, 10, 20, 50][this.focusCountIndex],
        rewardEnabled: rewardEnabled,
        password: rewardEnabled ? password : '',
        viewSeconds: viewSec
      })
      toast('已创建专注任务')
      this.showFocusForm = false
      this.reload()
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
      // 同一节点只能挂一个 bindSheet，用嵌套容器分别承载密码查看 / 专注表单两张弹层
      Column() {
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

            // 专注学习：全屏锁定练习，达成每日目标时长换限时查看密码的机会
            Row({ space: 10 }) {
              Column() {
                SectionTitle({ title: '专注学习' })
              }
              .layoutWeight(1)
              Text('＋ 新建专注')
                .fontSize(AppFont.Caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.OnBrand)
                .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
                .margin({ bottom: 10 })
                .onClick(() => {
                  this.openFocusForm()
                })
            }
            .width('100%')

            if (this.focusTasks.length === 0) {
              EmptyView({ icon: '🎯', text: '暂无专注任务。创建后每次达标时长都能获得查看密码的机会' })
            } else {
              ForEach(this.focusTasks, (task: FocusTask) => {
                Column() {
                  TechCard() {
                    Column({ space: AppSpace.Xs }) {
                      Row({ space: AppSpace.Xs }) {
                        Text(task.name)
                          .fontSize(AppFont.BodyL)
                          .fontWeight(FontWeight.Bold)
                          .fontColor($r('sys.color.font_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)
                        Text('删除')
                          .fontSize(11)
                          .fontColor(AppColor.Danger)
                          .onClick(() => {
                            this.removeFocusTask(task)
                          })
                      }
                      .width('100%')

                      Text('目标 ' + task.dailyTargetMin.toString() + ' 分 · 最少 ' + task.minSegmentMin.toString() +
                        ' 分 · 每 ' + task.verifyIntervalMin.toString() + ' 分验证')
                        .fontSize(11)
                        .fontColor($r('sys.color.font_tertiary'))
                        .width('100%')

                      Text(this.focusProgressText(task))
                        .fontSize(AppFont.Caption)
                        .fontColor($r('sys.color.font_secondary'))
                        .width('100%')

                      MiniBar({ ratio: this.focusCycleRatio(task) })

                      Row({ space: AppSpace.Sm }) {
                        Text('开始专注')
                          .fontSize(AppFont.Caption)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(AppColor.OnBrand)
                          .textAlign(TextAlign.Center)
                          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                          .borderRadius(AppRadius.Pill)
                          .backgroundColor(AppColor.Brand)
                          .onClick(() => {
                            this.startFocus(task)
                          })
                        if (task.rewardEnabled && task.viewChances > 0) {
                          Text('查看密码 · ' + task.viewChances.toString() + ' 次')
                            .fontSize(AppFont.Caption)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(AppColor.Brand)
                            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                            .borderRadius(AppRadius.Pill)
                            .border({ width: 1, color: AppColor.Brand })
                            .onClick(() => {
                              this.revealFor(task)
                            })
                        }
                      }
                      .width('100%')
                      .margin({ top: 2 })
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
                .margin({ bottom: AppSpace.Xs })
              }, (task: FocusTask) => this.focusKey(task))
            }

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
        .bindSheet($$this.showReveal, this.revealBuilder(), {
          height: 320,
          dragBar: true,
          preferType: SheetType.BOTTOM,
          backgroundColor: AppMaterial.SheetBackground,
          blurStyle: AppMaterial.SheetBlur,
          systemMaterial: AppMaterial.Sheet
        })
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.showFocusForm, this.focusFormBuilder(), {
        height: '88%',
        dragBar: true,
        preferType: SheetType.BOTTOM,
        backgroundColor: AppMaterial.SheetBackground,
        blurStyle: AppMaterial.SheetBlur,
        systemMaterial: AppMaterial.Sheet
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

  @Builder
  focusFormBuilder() {
    Scroll() {
      Column() {
        SheetHeader({ title: '新建专注任务' })
        Text('全屏锁定练习，配置创建后不可修改（只能删除重建）。')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .margin({ top: 6 })

        Text('任务名称').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如：前端面试冲刺', text: this.focusName })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.focusName = value
          })

        Text('每日目标总时长（分钟）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如 120', text: this.focusTarget })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .type(InputType.Number)
          .onChange((value: string) => {
            this.focusTarget = value
          })

        Text('单次最少时长（分钟）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如 30', text: this.focusMin })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .type(InputType.Number)
          .onChange((value: string) => {
            this.focusMin = value
          })

        Text('验证间隔（分钟）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如 5，每满该时长出一次算术验证', text: this.focusVerify })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .type(InputType.Number)
          .onChange((value: string) => {
            this.focusVerify = value
          })

        Text('每段后台次数上限').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如 3，切后台/息屏超过则本段作废', text: this.focusBgLimit })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .type(InputType.Number)
          .onChange((value: string) => {
            this.focusBgLimit = value
          })

        Text('每日完成次数上限').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如 3，每日累计每满目标时长算完成 1 次', text: this.focusDailyLimit })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .type(InputType.Number)
          .onChange((value: string) => {
            this.focusDailyLimit = value
          })

        Text('奖励').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: ['无奖励', '奖励密码'],
          selected: this.focusRewardIndex,
          onSelect: (index: number) => {
            this.focusRewardIndex = index
          }
        })

        if (this.focusRewardIndex === 1) {
          Text('任务密码').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
          TextInput({ placeholder: '每完成一次可获得限时查看机会', text: this.focusPassword })
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .fontSize(AppFont.Body)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(42)
            .align(Alignment.Start)
            .onChange((value: string) => {
              this.focusPassword = value
            })

          Text('密码可看时长（秒）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
          TextInput({ placeholder: '例如 60', text: this.focusViewSec })
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .fontSize(AppFont.Body)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(42)
            .align(Alignment.Start)
            .type(InputType.Number)
            .onChange((value: string) => {
              this.focusViewSec = value
            })
        }

        Text('练习模式').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: ['闪卡记忆', '填空选择'],
          selected: this.focusModeIndex,
          onSelect: (index: number) => {
            this.focusModeIndex = index
          }
        })

        Text('练习范围（可多选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.focusRanges, (range: string, index: number) => {
            Chip({
              text: this.focusRangeLabels[index],
              selected: this.focusRangeSelected[index] === true
            })
              .margin({ right: AppSpace.Xs, bottom: AppSpace.Xs })
              .onClick(() => {
                this.toggleFocusRange(index)
              })
          }, (range: string, index: number) => range + '-' + index.toString() + '-' + (this.focusRangeSelected[index] === true ? '1' : '0'))
        }
        .width('100%')

        Text('题目数量').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: ['5', '10', '20', '50'],
          selected: this.focusCountIndex,
          onSelect: (index: number) => {
            this.focusCountIndex = index
          }
        })

        Text('提示：今日累计每满一次目标时长即可查看一次密码，机会次日清零；查看限时 ' +
          (this.focusRewardIndex === 1 ? (isNaN(parseInt(this.focusViewSec)) ? '?' : this.focusViewSec) : '60') +
          ' 秒且不可复制、禁止截屏。练习与验证题均离线可用。')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .margin({ top: 14 })

        SheetSubmit({
          label: '创 建',
          busy: false,
          onSubmit: (): void => {
            this.saveFocusForm()
          }
        })
      }
      .width('100%')
      .padding({
        left: PAGE_PAD_H,
        right: PAGE_PAD_H,
        top: SHEET_PAD_TOP,
        bottom: SHEET_PAD_BOTTOM
      })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }

  @Builder
  revealBuilder() {
    PasswordRevealSheet({
      password: this.revealPassword,
      seconds: this.revealSeconds,
      onClosed: (): void => {
        this.showReveal = false
      }
    })
  }
}

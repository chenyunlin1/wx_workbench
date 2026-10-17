import { confirm, toast } from '../../common/AppKit'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { WindowUtils } from '../../utils/WindowUtils'
import {
  FocusQuestion,
  FocusStudyService,
  FocusTask,
  FOCUS_STATUS_PAUSED,
  FOCUS_STATUS_PAUSED_BG,
  FOCUS_STATUS_RUNNING,
  FOCUS_STATUS_VERIFY
} from '../../service/FocusStudyService'
import { FillblankQuestion, FlashcardQuestion } from '../../model/Models'
import { PasswordRevealSheet } from '../../components/FocusPasswordSheet'
import { MiniBar, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, TechCard } from '../../components/Ui'

/**
 * 专注学习锁定页：全屏知识练习，Tab / 返回键全屏蔽。
 * 计时与状态机在 FocusStudyService，本页只负责渲染与交互。
 */
@ComponentV2
export struct FocusStudyPage {
  @Param nav: NavPathStack = new NavPathStack()
  @Local task: FocusTask | null = null
  @Local invalid: boolean = false
  @Local status: string = 'idle'
  @Local elapsedSec: number = 0
  @Local bgCount: number = 0
  @Local todaySec: number = 0
  @Local completions: number = 0
  @Local viewLeft: number = 0
  @Local remainingSec: number = 0
  // 练习
  @Local questions: FocusQuestion[] = []
  @Local current: number = 0
  @Local revealed: boolean = false
  @Local selectedOption: string = ''
  // 验证
  @Local verifyOn: boolean = false
  @Local vA: number = 0
  @Local vB: number = 0
  @Local vOp: string = '+'
  @Local vInput: string = ''
  private vAnswer: number = 0
  // 结算
  @Local settled: boolean = false
  @Local sSettledSec: number = 0
  @Local sTodaySec: number = 0
  @Local sEarned: number = 0
  @Local sCompletions: number = 0
  @Local sDailyLimit: number = 0
  // 作废
  @Local voided: boolean = false
  @Local voidText: string = ''
  // 密码
  @Local showPassword: boolean = false
  @Local revealPassword: string = ''
  @Local revealSeconds: number = 60
  private timerId: number = -1

  aboutToAppear(): void {
    const id = AppStorage.get<number>('focusTaskId')
    const task = id === undefined ? undefined : FocusStudyService.get(id)
    if (task === undefined) {
      this.invalid = true
      return
    }
    this.task = task
    const notice = FocusStudyService.takeNotice()
    if (notice !== null && notice.taskId === task.id) {
      this.voided = true
      this.voidText = notice.reason === 'bgLimit' ? '本段因切后台次数超限已作废' : '上次专注因 App 被关闭已作废'
      this.refresh()
      return
    }
    if (FocusStudyService.active() === null) {
      if (!this.beginSegment()) {
        this.nav.pop()
        return
      }
    }
    this.loadBatch()
    this.startTimer()
    this.refresh()
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    // 正常路径退出时 active 已清空；走到这里还残留说明是非正常离开，按作废处理
    if (FocusStudyService.active() !== null && !this.settled) {
      FocusStudyService.voidSegment()
    }
    Session.bumpDataVersion()
  }

  private startTimer(): void {
    if (this.timerId >= 0) {
      return
    }
    this.timerId = setInterval(() => {
      this.onTick()
    }, 1000)
  }

  private onTick(): void {
    const task = this.task
    if (task === null) {
      return
    }
    const event = FocusStudyService.tick()
    if (event === 'verify') {
      this.openVerify()
      this.refresh()
      return
    }
    if (FocusStudyService.active() === null && !this.settled && !this.voided) {
      const notice = FocusStudyService.takeNotice()
      if (notice !== null && notice.taskId === task.id) {
        this.voided = true
        this.voidText = notice.reason === 'bgLimit' ? '本段因切后台次数超限已作废' : '本次专注已结束'
        this.verifyOn = false
      }
    }
    this.refresh()
  }

  private beginSegment(): boolean {
    const task = this.task
    if (task === null) {
      return false
    }
    const reason = FocusStudyService.canStartReason(task)
    if (reason.length > 0) {
      toast(reason)
      return false
    }
    if (!FocusStudyService.startSegment(task.id)) {
      toast('已有专注进行中')
      return false
    }
    return true
  }

  private loadBatch(): void {
    const task = this.task
    if (task === null) {
      return
    }
    this.questions = FocusStudyService.generateBatch(task)
    this.current = 0
    this.revealed = false
    this.selectedOption = ''
  }

  private refresh(): void {
    const task = this.task
    if (task === null) {
      return
    }
    const active = FocusStudyService.active()
    this.status = active === null ? 'idle' : active.status
    this.elapsedSec = active === null ? 0 : active.elapsedSec
    this.bgCount = active === null ? 0 : active.bgCount
    this.todaySec = task.todaySec + this.elapsedSec
    this.completions = task.completions
    this.viewLeft = task.viewChances
    this.remainingSec = task.completions >= task.dailyLimit ? -1 : this.remainingFrom(this.todaySec)
  }

  private remainingFrom(sec: number): number {
    const task = this.task
    if (task === null) {
      return 0
    }
    const targetSec = task.dailyTargetMin * 60
    if (targetSec <= 0) {
      return 0
    }
    return targetSec - (sec % targetSec)
  }

  private cycleRatio(): number {
    const task = this.task
    if (task === null) {
      return 0
    }
    const targetSec = task.dailyTargetMin * 60
    if (targetSec <= 0) {
      return 0
    }
    if (task.completions >= task.dailyLimit) {
      return 1
    }
    const ratio = (this.todaySec % targetSec) / targetSec
    return ratio > 1 ? 1 : ratio
  }

  /* ---------------- 结束 / 结算 / 作废 ---------------- */

  private attemptEnd(): void {
    const task = this.task
    if (task === null || this.voided || this.settled) {
      this.nav.pop()
      return
    }
    const active = FocusStudyService.active()
    if (active === null) {
      this.nav.pop()
      return
    }
    if (active.elapsedSec < task.minSegmentMin * 60) {
      confirm('本段不足最少 ' + task.minSegmentMin.toString() + ' 分钟，结束将作废本段。确定结束吗？', () => {
        FocusStudyService.voidSegment()
        toast('本段已作废')
        this.nav.pop()
      })
      return
    }
    confirm('本段已专注 ' + this.shortDur(active.elapsedSec) + '，结束并结算到今日累计？', () => {
      this.doSettle()
    })
  }

  private doSettle(): void {
    const result = FocusStudyService.settle()
    if (result === null) {
      this.nav.pop()
      return
    }
    this.sSettledSec = result.settledSec
    this.sTodaySec = result.todaySec
    this.sEarned = result.earned
    this.sCompletions = result.completions
    this.sDailyLimit = result.dailyLimit
    this.settled = true
    this.verifyOn = false
    this.refresh()
  }

  private continueNext(): void {
    this.settled = false
    if (!this.beginSegment()) {
      this.settled = true
      return
    }
    this.loadBatch()
    this.refresh()
  }

  private restartAfterVoid(): void {
    this.voided = false
    if (!this.beginSegment()) {
      this.voided = true
      return
    }
    this.loadBatch()
    this.startTimer()
    this.refresh()
  }

  /* ---------------- 验证题 ---------------- */

  private openVerify(): void {
    const question = FocusStudyService.nextArithmetic()
    this.vA = question.a
    this.vB = question.b
    this.vOp = question.op
    this.vAnswer = question.answer
    this.vInput = ''
    this.verifyOn = true
  }

  private submitVerify(): void {
    const value = parseInt(this.vInput)
    if (isNaN(value)) {
      toast('请输入答案')
      return
    }
    if (value === this.vAnswer) {
      toast('回答正确，继续专注')
      this.verifyOn = false
      FocusStudyService.markVerifyPassed()
      this.refresh()
      return
    }
    toast('答错了，换一题再试')
    const question = FocusStudyService.nextArithmetic()
    this.vA = question.a
    this.vB = question.b
    this.vOp = question.op
    this.vAnswer = question.answer
    this.vInput = ''
  }

  /* ---------------- 密码查看 ---------------- */

  private openReveal(): void {
    const task = this.task
    if (task === null || !task.rewardEnabled || this.viewLeft <= 0) {
      toast('当前没有可用的查看机会')
      return
    }
    confirm('查看密码将消耗 1 次机会（剩余 ' + this.viewLeft.toString() + ' 次），确定查看吗？', (): void => {
      if (!FocusStudyService.consumeView(task.id)) {
        toast('当前没有可用的查看机会')
        return
      }
      this.revealPassword = task.password
      this.revealSeconds = task.viewSeconds
      this.showPassword = true
      this.refresh()
    })
  }

  /* ---------------- 练习交互 ---------------- */

  private answerFlashcard(): void {
    this.next()
  }

  private answerOption(option: string): void {
    if (this.selectedOption.length > 0) {
      return
    }
    const question = this.questions[this.current]
    if (question === undefined || question.type !== 'fillblank') {
      return
    }
    this.selectedOption = option
  }

  private next(): void {
    if (this.questions.length === 0) {
      return
    }
    if (this.current >= this.questions.length - 1) {
      this.loadBatch()
      toast('本批完成，继续下一批')
      return
    }
    this.current += 1
    this.revealed = false
    this.selectedOption = ''
  }

  private currentType(): string {
    const question = this.questions[this.current]
    return question === undefined ? '' : question.type
  }

  private currentTitle(): string {
    const question = this.questions[this.current]
    return question === undefined ? '' : question.title
  }

  private currentContent(): string {
    const question = this.questions[this.current]
    if (question === undefined || question.type !== 'flashcard') {
      return ''
    }
    return (question as FlashcardQuestion).content
  }

  private currentTags(): string {
    const question = this.questions[this.current]
    if (question === undefined || question.tags.length === 0) {
      return ''
    }
    return '# ' + question.tags.join(' · ')
  }

  private currentOptions(): string[] {
    const question = this.questions[this.current]
    if (question === undefined || question.type !== 'fillblank') {
      return []
    }
    return (question as FillblankQuestion).options
  }

  private currentCorrect(): string {
    const question = this.questions[this.current]
    if (question === undefined || question.type !== 'fillblank') {
      return ''
    }
    return (question as FillblankQuestion).correctAnswer
  }

  private optionColor(option: string): ResourceColor {
    if (this.selectedOption.length === 0) {
      return AppColor.Divider
    }
    if (option === this.currentCorrect()) {
      return AppColor.Brand
    }
    if (option === this.selectedOption) {
      return Theme.DANGER
    }
    return AppColor.Divider
  }

  private optionBg(option: string): ResourceColor {
    if (this.selectedOption.length === 0) {
      return $r('sys.color.comp_background_tertiary')
    }
    if (option === this.currentCorrect()) {
      return AppColor.BrandSoft
    }
    if (option === this.selectedOption) {
      return Theme.DANGER_SOFT
    }
    return $r('sys.color.comp_background_tertiary')
  }

  /* ---------------- 文本 ---------------- */

  private durText(total: number): string {
    const safe = total < 0 ? 0 : Math.floor(total)
    const h = Math.floor(safe / 3600)
    const m = Math.floor((safe % 3600) / 60)
    const s = safe % 60
    const mm = m < 10 ? '0' + m.toString() : m.toString()
    const ss = s < 10 ? '0' + s.toString() : s.toString()
    if (h > 0) {
      return h.toString() + ':' + mm + ':' + ss
    }
    return mm + ':' + ss
  }

  private shortDur(total: number): string {
    const safe = total < 0 ? 0 : Math.floor(total)
    const m = Math.floor(safe / 60)
    const s = safe % 60
    if (m <= 0) {
      return s.toString() + ' 秒'
    }
    if (s === 0) {
      return m.toString() + ' 分钟'
    }
    return m.toString() + ' 分 ' + s.toString() + ' 秒'
  }

  private taskName(): string {
    return this.task === null ? '' : this.task.name
  }

  private dailyLimit(): number {
    return this.task === null ? 0 : this.task.dailyLimit
  }

  private minPairText(): string {
    return Math.floor(this.todaySec / 60).toString() + '/' + (this.task === null ? 0 : this.task.dailyTargetMin).toString() + ' 分'
  }

  private remainText(): string {
    if (this.remainingSec < 0) {
      return '已完成'
    }
    return this.durText(this.remainingSec)
  }

  private statLabel(kind: number): string {
    if (kind === 0) {
      return '本次专注'
    }
    return kind === 1 ? '今日累计' : '距下一次完成'
  }

  private statValue(kind: number): string {
    if (kind === 0) {
      return this.durText(this.elapsedSec)
    }
    if (kind === 1) {
      return this.minPairText()
    }
    return this.remainText()
  }

  private statAccent(kind: number): ResourceColor {
    if (kind === 0) {
      return AppColor.Brand
    }
    if (kind === 1) {
      return AppColor.BrandDark
    }
    return this.remainingSec < 0 ? $r('sys.color.font_tertiary') : Theme.WARN
  }

  build() {
    NavDestination() {
      Stack() {
        if (this.invalid) {
          this.invalidView()
        } else if (this.task !== null) {
          this.sessionView()
        }
        if (this.voided && !this.invalid) {
          this.voidOverlay()
        }
        if (this.settled && !this.voided) {
          this.settleOverlay()
        }
        if (this.verifyOn && this.status === FOCUS_STATUS_VERIFY && !this.voided && !this.settled) {
          this.verifyOverlay()
        }
        if (!this.verifyOn && (this.status === FOCUS_STATUS_PAUSED || this.status === FOCUS_STATUS_PAUSED_BG)
          && !this.settled && !this.voided && !this.invalid) {
          this.pauseOverlay()
        }
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.showPassword, this.passwordBuilder(), {
        height: 320,
        dragBar: true,
        preferType: SheetType.BOTTOM,
        backgroundColor: AppMaterial.SheetBackground,
        blurStyle: AppMaterial.SheetBlur,
        systemMaterial: AppMaterial.Sheet
      })
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_primary'))
    .onBackPressed((): boolean => {
      this.attemptEnd()
      return true
    })
  }

  @Builder
  passwordBuilder() {
    PasswordRevealSheet({
      password: this.revealPassword,
      seconds: this.revealSeconds,
      onClosed: (): void => {
        this.showPassword = false
      }
    })
  }

  @Builder
  invalidView() {
    Column({ space: AppSpace.Sm }) {
      Text('🌀')
        .fontSize(40)
      Text('专注任务不存在或已删除')
        .fontSize(AppFont.BodyL)
        .fontColor($r('sys.color.font_secondary'))
      Text('返回')
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.OnBrand)
        .textAlign(TextAlign.Center)
        .width(180)
        .height(44)
        .borderRadius(AppRadius.Pill)
        .backgroundColor(AppColor.Brand)
        .margin({ top: AppSpace.Sm })
        .onClick(() => {
          this.nav.pop()
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  sessionView() {
    Column() {
      Row({ space: AppSpace.Xs }) {
        Column({ space: 4 }) {
          Text(this.taskName())
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text('全屏专注中 · 退出会结束本段')
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.status === FOCUS_STATUS_RUNNING) {
          Text('暂停')
            .fontSize(AppFont.Caption)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
            .borderRadius(AppRadius.Pill)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .onClick(() => {
              FocusStudyService.pauseManual()
              this.refresh()
            })
        }
        Text('结束本段')
          .fontSize(AppFont.Caption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.OnBrand)
          .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
          .borderRadius(AppRadius.Pill)
          .backgroundColor(AppColor.Brand)
          .onClick(() => {
            this.attemptEnd()
          })
      }
      .width('100%')

      // 统计、进度与练习卡放进同一个页面级滚动：卡片按文字自然高度渲染、整页一起滚，
      // 不再单独留一块只能内部滚动的卡片区（顶栏固定，保证出口按钮随时可点）
      Scroll() {
        Column() {
          Row() {
            this.statCol(0)
            this.statCol(1)
            this.statCol(2)
          }
      .width('100%')
      .margin({ top: AppSpace.Md })
      .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm })
      .borderRadius(AppRadius.Md)
      .backgroundColor($r('sys.color.comp_background_primary'))

      Row({ space: AppSpace.Xs }) {
        Text('完成 ' + this.completions.toString() + ' / ' + this.dailyLimit().toString() + ' 次')
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
        Text(this.completions >= this.dailyLimit() ? '今日次数已用完' : '本轮进度 ' + Math.round(this.cycleRatio() * 100).toString() + '%')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .margin({ top: AppSpace.Sm })

      Column() {
        MiniBar({ ratio: this.cycleRatio() })
      }
      .width('100%')
      .margin({ top: 6, bottom: AppSpace.Sm })

          if (this.questions.length === 0) {
            TechCard() {
              Column({ space: AppSpace.Xs }) {
                Text('📭')
                  .fontSize(30)
                Text('当前练习范围暂无可用笔记')
                  .fontSize(AppFont.Body)
                  .fontColor($r('sys.color.font_secondary'))
                Text('请先回「备忘」同步知识库后再试')
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .width('100%')
              .padding({ top: 20, bottom: 20 })
              .alignItems(HorizontalAlign.Center)
            }
          } else {
            Column() {
              TechCard() {
                Column({ space: AppSpace.Sm }) {
                  Row({ space: AppSpace.Xs }) {
                    Text(this.currentType() === 'flashcard' ? '闪卡' : '填空')
                      .fontSize(10)
                      .fontColor(this.currentType() === 'flashcard' ? AppColor.BrandDark : AppColor.Brand)
                      .width(52)
                      .textAlign(TextAlign.Center)
                      .padding({ top: 3, bottom: 3 })
                      .borderRadius(AppRadius.Pill)
                      .border({ width: 1, color: this.currentType() === 'flashcard' ? AppColor.BrandDark : AppColor.Brand })
                    Blank()
                    Text('第 ' + (this.current + 1).toString() + ' / ' + this.questions.length.toString() + ' 题')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_tertiary'))
                  }
                  .width('100%')

                  Text(this.currentTitle())
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                    .width('100%')

                  if (this.currentType() === 'flashcard') {
                    Text(this.revealed ? this.currentContent() : '点击下方“显示答案”查看内容')
                      .fontSize(AppFont.Body)
                      .fontColor(this.revealed ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
                      .lineHeight(22)
                      .width('100%')
                    if (this.currentTags().length > 0) {
                      Text(this.currentTags())
                        .fontSize(10)
                        .fontColor(AppColor.BrandDark)
                        .width('100%')
                    }
                  } else {
                    ForEach(this.currentOptions(), (option: string) => {
                      Text(option)
                        .fontSize(AppFont.Body)
                        .fontColor(this.optionColor(option))
                        .width('100%')
                        .padding(AppSpace.Sm)
                        .borderRadius(AppRadius.Md)
                        .backgroundColor(this.optionBg(option))
                        .border({ width: 1, color: this.optionColor(option) })
                        .margin({ bottom: AppSpace.Xs })
                        .onClick(() => {
                          this.answerOption(option)
                        })
                    }, (option: string) => option + this.selectedOption)
                    if (this.selectedOption.length > 0) {
                      Text('正确答案：' + this.currentCorrect())
                        .fontSize(AppFont.Caption)
                        .fontColor(AppColor.Brand)
                        .width('100%')
                    }
                  }
                }
                .width('100%')
              }

              if (this.currentType() === 'flashcard') {
                if (!this.revealed) {
                  Text('显示答案')
                    .fontSize(AppFont.Body)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColor.OnBrand)
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .height(46)
                    .borderRadius(AppRadius.Pill)
                    .backgroundColor(AppColor.Brand)
                    .margin({ top: 14 })
                    .onClick(() => {
                      this.revealed = true
                    })
                } else {
                  Row({ space: 10 }) {
                    Text('😅 忘了')
                      .fontSize(13)
                      .fontColor(Theme.DANGER)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .height(44)
                      .borderRadius(AppRadius.Pill)
                      .border({ width: 1, color: Theme.DANGER })
                      .onClick(() => {
                        this.answerFlashcard()
                      })
                    Text('🤔 模糊')
                      .fontSize(13)
                      .fontColor(Theme.WARN)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .height(44)
                      .borderRadius(AppRadius.Pill)
                      .border({ width: 1, color: Theme.WARN })
                      .onClick(() => {
                        this.answerFlashcard()
                      })
                    Text('😄 记得')
                      .fontSize(13)
                      .fontColor(AppColor.Brand)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .height(44)
                      .borderRadius(AppRadius.Pill)
                      .border({ width: 1, color: AppColor.Brand })
                      .onClick(() => {
                        this.answerFlashcard()
                      })
                  }
                  .width('100%')
                  .margin({ top: 14 })
                }
              } else if (this.selectedOption.length > 0) {
                Text(this.current >= this.questions.length - 1 ? '下一批' : '下一题')
                  .fontSize(AppFont.Body)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColor.OnBrand)
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .height(46)
                  .borderRadius(AppRadius.Pill)
                  .backgroundColor(AppColor.Brand)
                  .margin({ top: 14 })
                  .onClick(() => {
                    this.next()
                  })
              }
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ bottom: PAGE_SCROLL_BOTTOM })
        .constraintSize({ minHeight: '100%' })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: PAGE_PAD_H,
      right: PAGE_PAD_H,
      top: WindowUtils.getStatusBarHeightVp() + 12
    })
  }

  @Builder
  statCol(kind: number) {
    Column({ space: 4 }) {
      // 状态必须在 Text 的更新闭包内读取，才能随计时每秒刷新（builder 按值传参会冻结）
      Text(this.statValue(kind))
        .fontSize(AppFont.Title)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.statAccent(kind))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.statLabel(kind))
        .fontSize(10)
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
  }

  @Builder
  pauseOverlay() {
    Column({ space: AppSpace.Sm }) {
      TechCard() {
        Column({ space: AppSpace.Sm }) {
          Text('⏸ 已暂停')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          if (this.status === FOCUS_STATUS_PAUSED_BG) {
            Text('切后台已计 ' + this.bgCount.toString() + ' / ' + (this.task === null ? 0 : this.task.bgLimit).toString() + ' 次，超过上限本段作废')
              .fontSize(11)
              .fontColor(Theme.WARN)
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
            Text('已手动暂停，专注计时停止')
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
          }
          Text('继续专注')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.OnBrand)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(46)
            .borderRadius(AppRadius.Pill)
            .backgroundColor(AppColor.Brand)
            .margin({ top: AppSpace.Xs })
            .onClick(() => {
              FocusStudyService.resume()
              this.refresh()
            })
          Text('结束本段')
            .fontSize(AppFont.Caption)
            .fontColor($r('sys.color.font_tertiary'))
            .padding(AppSpace.Xs)
            .onClick(() => {
              this.attemptEnd()
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpace.Lg)
    .backgroundColor('#99000000')
  }

  @Builder
  verifyOverlay() {
    Column({ space: AppSpace.Sm }) {
      TechCard() {
        Column({ space: AppSpace.Sm }) {
          Text('🧮 专注验证')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('答对即可继续专注；答错换一题，不罚时')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .textAlign(TextAlign.Center)
            .width('100%')
          Text(this.vA.toString() + ' ' + this.vOp + ' ' + this.vB.toString() + ' = ?')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.Brand)
            .margin({ top: AppSpace.Xs, bottom: AppSpace.Xs })
          TextInput({ placeholder: '输入答案', text: this.vInput })
            .type(InputType.Number)
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .fontSize(AppFont.BodyL)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(46)
            .width('100%')
            .onChange((value: string) => {
              this.vInput = value
            })
          Text('提交答案')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.OnBrand)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(46)
            .borderRadius(AppRadius.Pill)
            .backgroundColor(AppColor.Brand)
            .margin({ top: AppSpace.Xs })
            .onClick(() => {
              this.submitVerify()
            })
          Text('结束本段')
            .fontSize(AppFont.Caption)
            .fontColor($r('sys.color.font_tertiary'))
            .padding(AppSpace.Xs)
            .onClick(() => {
              this.attemptEnd()
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpace.Lg)
    .backgroundColor('#99000000')
  }

  @Builder
  voidOverlay() {
    Column({ space: AppSpace.Sm }) {
      TechCard() {
        Column({ space: AppSpace.Sm }) {
          Text('🚫 本段已作废')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(this.voidText)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
          Row({ space: AppSpace.Xs }) {
            Text('重新开始一段')
              .fontSize(AppFont.Body)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.OnBrand)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(AppRadius.Pill)
              .backgroundColor(AppColor.Brand)
              .onClick(() => {
                this.restartAfterVoid()
              })
            Text('退出专注')
              .fontSize(AppFont.Body)
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(AppRadius.Pill)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onClick(() => {
                this.nav.pop()
              })
          }
          .width('100%')
          .margin({ top: AppSpace.Xs })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpace.Lg)
    .backgroundColor('#99000000')
  }

  @Builder
  settleOverlay() {
    Column({ space: AppSpace.Sm }) {
      TechCard() {
        Column({ space: AppSpace.Sm }) {
          Text('✅ 本段已结算')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('本次专注 ' + this.shortDur(this.sSettledSec) + '，今日累计 ' + Math.floor(this.sTodaySec / 60).toString() + ' 分')
            .fontSize(AppFont.Caption)
            .fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
          if (this.sEarned > 0) {
            Text('🎉 完成第 ' + this.sCompletions.toString() + ' 次，获得 ' + this.sEarned.toString() + ' 次查看密码机会')
              .fontSize(AppFont.Caption)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.Brand)
              .textAlign(TextAlign.Center)
              .width('100%')
          } else if (this.sCompletions >= this.sDailyLimit) {
            Text('今日完成次数已达上限（' + this.sDailyLimit.toString() + ' 次），明天再来')
              .fontSize(AppFont.Caption)
              .fontColor($r('sys.color.font_tertiary'))
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
            Text('距下一次完成还差 ' + this.shortDur(this.remainingFrom(this.sTodaySec)))
              .fontSize(AppFont.Caption)
              .fontColor($r('sys.color.font_tertiary'))
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          if (this.viewLeft > 0 && this.task !== null && this.task.rewardEnabled) {
            Text('查看密码（' + (this.task === null ? 0 : this.task.viewSeconds).toString() + ' 秒）')
              .fontSize(AppFont.BodyL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.OnBrand)
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(46)
              .borderRadius(AppRadius.Pill)
              .backgroundColor(AppColor.Brand)
              .margin({ top: AppSpace.Xs })
              .onClick(() => {
                this.openReveal()
              })
          }
          Row({ space: AppSpace.Xs }) {
            Text('继续下一段')
              .fontSize(AppFont.Body)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.OnBrand)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(AppRadius.Pill)
              .backgroundColor(AppColor.Brand)
              .onClick(() => {
                this.continueNext()
              })
            Text('退出专注')
              .fontSize(AppFont.Body)
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(AppRadius.Pill)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onClick(() => {
                this.nav.pop()
              })
          }
          .width('100%')
          .margin({ top: AppSpace.Xs })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpace.Lg)
    .backgroundColor('#99000000')
  }
}

import { toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { FillblankQuestion, FlashcardQuestion } from '../../model/Models'
import { OptionChips, PAGE_PAD_H, PageHeader, SectionTitle, TechCard } from '../../components/Ui'

type Question = FlashcardQuestion | FillblankQuestion

/**
 * 知识练习：配置 → 答题 → 结果 三个阶段。
 */
@Component
export struct PracticePage {
  @Consume('nav') nav: NavPathStack
  @State phase: number = 0 // 0 配置 / 1 答题 / 2 结果
  @State modeIndex: number = 0
  @State rangeIndex: number = 0
  @State countIndex: number = 1
  @State tags: string[] = []
  @State ranges: string[] = ['all', 'learned', 'unlearned']
  @State rangeLabels: string[] = ['全部笔记', '已学习笔记', '未学习笔记']
  @State noteCount: number = -1
  @State questions: Question[] = []
  @State current: number = 0
  @State revealed: boolean = false
  @State selectedOption: string = ''
  @State remembered: number = 0
  @State fuzzy: number = 0
  @State forgotten: number = 0
  @State startTime: number = 0
  @State elapsed: number = 0
  @State loading: boolean = false

  aboutToAppear(): void {
    Api.practiceTags().then((list) => {
      this.tags = list
      const nextRanges = this.ranges.concat(this.tags)
      const nextLabels = this.rangeLabels.concat(this.tags)
      this.ranges = nextRanges
      this.rangeLabels = nextLabels
    }).catch(() => {
    })
    this.loadCount()
  }

  currentRange(): string {
    return this.ranges[this.rangeIndex]
  }

  loadCount(): void {
    this.noteCount = -1
    Api.practiceCount(this.currentRange()).then((count) => {
      this.noteCount = count
    }).catch(() => {
      this.noteCount = 0
    })
  }

  startPractice(): void {
    if (this.noteCount <= 0) {
      toast('当前范围内没有可用笔记，请先补充知识库')
      return
    }
    this.loading = true
    Api.generatePractice(this.modeIndex === 0 ? 'flashcard' : 'fillblank',
      this.currentRange(), [5, 10, 20, 50][this.countIndex]).then((list) => {
      if (list.length === 0) {
        toast('没有生成可用题目，请调整范围')
        return
      }
      this.questions = list
      this.current = 0
      this.revealed = false
      this.selectedOption = ''
      this.remembered = 0
      this.fuzzy = 0
      this.forgotten = 0
      this.startTime = Date.now()
      this.phase = 1
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '生成题目失败')
    }).finally(() => {
      this.loading = false
    })
  }

  answer(result: string): void {
    if (result === 'remembered') {
      this.remembered++
    } else if (result === 'fuzzy') {
      this.fuzzy++
    } else {
      this.forgotten++
    }
    this.next()
  }

  answerOption(option: string): void {
    if (this.selectedOption.length > 0) {
      return
    }
    this.selectedOption = option
    const q = this.questions[this.current]
    if (q !== undefined && q.type === 'fillblank') {
      const fill = q as FillblankQuestion
      if (option === fill.correctAnswer) {
        this.remembered++
      } else {
        this.forgotten++
      }
    }
  }

  next(): void {
    if (this.current >= this.questions.length - 1) {
      this.finish()
    } else {
      this.current++
      this.revealed = false
      this.selectedOption = ''
    }
  }

  finish(): void {
    this.elapsed = Math.round((Date.now() - this.startTime) / 1000)
    Api.submitPracticeResult({
      mode: this.modeIndex === 0 ? 'flashcard' : 'fillblank',
      total: this.questions.length,
      remembered: this.remembered,
      fuzzy: this.fuzzy,
      forgotten: this.forgotten,
      duration: this.elapsed
    }).catch(() => {
    })
    this.phase = 2
  }

  backToConfig(): void {
    this.phase = 0
    this.loadCount()
  }

  /* 当前题目的展示数据（@Builder 内不能声明局部变量，统一走方法） */

  private currentType(): string {
    const q = this.questions[this.current]
    return q === undefined ? '' : q.type
  }

  private currentTitle(): string {
    const q = this.questions[this.current]
    if (q === undefined) {
      return ''
    }
    return q.title
  }

  private currentContent(): string {
    const q = this.questions[this.current]
    if (q === undefined || q.type !== 'flashcard') {
      return ''
    }
    return (q as FlashcardQuestion).content
  }

  private currentTags(): string {
    const q = this.questions[this.current]
    if (q === undefined || q.tags.length === 0) {
      return ''
    }
    return '# ' + q.tags.join(' · ')
  }

  private currentOptions(): string[] {
    const q = this.questions[this.current]
    if (q === undefined || q.type !== 'fillblank') {
      return []
    }
    return (q as FillblankQuestion).options
  }

  private currentCorrect(): string {
    const q = this.questions[this.current]
    if (q === undefined || q.type !== 'fillblank') {
      return ''
    }
    return (q as FillblankQuestion).correctAnswer
  }

  optionColor(option: string): string {
    if (this.selectedOption.length === 0) {
      return Theme.BORDER_GLOW
    }
    if (option === this.currentCorrect()) {
      return Theme.MINT
    }
    if (option === this.selectedOption) {
      return Theme.DANGER
    }
    return Theme.BORDER
  }

  optionBg(option: string): string {
    if (this.selectedOption.length === 0) {
      return Theme.INPUT_BG
    }
    if (option === this.currentCorrect()) {
      return Theme.MINT_SOFT
    }
    if (option === this.selectedOption) {
      return Theme.DANGER_SOFT
    }
    return Theme.INPUT_BG
  }

  build() {
    NavDestination() {
    Stack() {
      Column() {
        PageHeader({ title: '知识练习' })

        if (this.phase === 0) {
          this.configView()
        } else if (this.phase === 1) {
          this.sessionView()
        } else {
          this.resultView()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }

  @Builder
  configView() {
    Scroll() {
      Column() {
        Column() {
        TechCard() {
          Column({ space: 12 }) {
            SectionTitle({ title: '练习模式' })
            OptionChips({
              options: ['闪卡记忆', '填空选择'],
              selected: this.modeIndex,
              onSelect: (index: number) => {
                this.modeIndex = index
              }
            })

            Text('练习范围').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 8 })
            OptionChips({
              options: this.ranges,
              labels: this.rangeLabels,
              selected: this.rangeIndex,
              onSelect: (index: number) => {
                this.rangeIndex = index
                this.loadCount()
              }
            })

            Text('题目数量').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 8 })
            OptionChips({
              options: ['5', '10', '20', '50'],
              selected: this.countIndex,
              onSelect: (index: number) => {
                this.countIndex = index
              }
            })

            Text(this.noteCount < 0 ? '统计中…' : '当前范围共 ' + this.noteCount + ' 篇笔记')
              .fontSize(12)
              .fontColor(Theme.CYAN)
              .margin({ top: 8 })

            Text(this.loading ? '生成中…' : '开始练习')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(46)
              .borderRadius(12)
              .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
              .margin({ top: 10 })
              .onClick(() => {
                if (!this.loading) {
                  this.startPractice()
                }
              })
          }
          .width('100%')
        }
        }
          .width('100%')
        .margin({ top: 4 })
      }
      .padding({ bottom: 60 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
  }

  @Builder
  sessionView() {
    Column() {
      Row({ space: 10 }) {
        Text('第 ' + (this.current + 1) + ' / ' + this.questions.length + ' 题')
          .fontSize(12)
          .fontColor(Theme.CYAN)
        Stack({ alignContent: Alignment.Start }) {
          Column()
            .width('100%')
            .height(5)
            .borderRadius(3)
            .backgroundColor(Theme.BORDER)
          Column()
            .height(5)
            .borderRadius(3)
            .linearGradient({ angle: 90, colors: Theme.MINT_COLORS })
            .width((this.questions.length === 0 ? 0 : (this.current + 1) / this.questions.length * 100) + '%')
        }
        .width('100%')
        .height(5)
      }
      .width('100%')
      .padding({ bottom: 10 })

      Scroll() {
        Column() {
          TechCard() {
            Column({ space: 12 }) {
              Text(this.currentType() === 'flashcard' ? '闪卡' : '填空')
                .fontSize(10)
                .fontColor(this.currentType() === 'flashcard' ? Theme.VIOLET : Theme.CYAN)
                .width(52)
                .textAlign(TextAlign.Center)
                .padding({ top: 3, bottom: 3 })
                .borderRadius(999)
                .border({ width: 1, color: this.currentType() === 'flashcard' ? Theme.VIOLET : Theme.CYAN })

              Text(this.currentTitle())
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .width('100%')

              if (this.currentType() === 'flashcard') {
                Text(this.revealed ? this.currentContent() : '点击下方“显示答案”查看内容')
                  .fontSize(14)
                  .fontColor(this.revealed ? Theme.TEXT_SUB : Theme.TEXT_FAINT)
                  .lineHeight(22)
                  .width('100%')
                if (this.currentTags().length > 0) {
                  Text(this.currentTags())
                    .fontSize(10)
                    .fontColor(Theme.VIOLET)
                    .width('100%')
                }
              } else {
                ForEach(this.currentOptions(), (option: string) => {
                  Text(option)
                    .fontSize(14)
                    .fontColor(this.optionColor(option))
                    .width('100%')
                    .padding(12)
                    .borderRadius(12)
                    .backgroundColor(this.optionBg(option))
                    .border({ width: 1, color: this.optionColor(option) })
                    .margin({ bottom: 8 })
                    .onClick(() => {
                      this.answerOption(option)
                    })
                }, (option: string) => option + this.selectedOption)
                if (this.selectedOption.length > 0) {
                  Text('正确答案：' + this.currentCorrect())
                    .fontSize(12)
                    .fontColor(Theme.MINT)
                    .width('100%')
                }
              }
            }
            .width('100%')
          }

          if (this.currentType() === 'flashcard') {
            if (!this.revealed) {
              Text('显示答案')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(46)
                .borderRadius(12)
                .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
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
                  .borderRadius(12)
                  .border({ width: 1, color: Theme.DANGER })
                  .onClick(() => {
                    this.answer('forgotten')
                  })
                Text('🤔 模糊')
                  .fontSize(13)
                  .fontColor(Theme.WARN)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .height(44)
                  .borderRadius(12)
                  .border({ width: 1, color: Theme.WARN })
                  .onClick(() => {
                    this.answer('fuzzy')
                  })
                Text('😄 记得')
                  .fontSize(13)
                  .fontColor(Theme.MINT)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .height(44)
                  .borderRadius(12)
                  .border({ width: 1, color: Theme.MINT })
                  .onClick(() => {
                    this.answer('remembered')
                  })
              }
              .width('100%')
              .margin({ top: 14 })
            }
          } else if (this.selectedOption.length > 0) {
            Text(this.current >= this.questions.length - 1 ? '查看结果' : '下一题')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(46)
              .borderRadius(12)
              .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
              .margin({ top: 14 })
              .onClick(() => {
                this.next()
              })
          }
        }
        .padding({ bottom: 60 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .layoutWeight(1)
  }

  @Builder
  resultView() {
    Column() {
      Column() {
      TechCard() {
        Column({ space: 14 }) {
          Text('🎉')
            .fontSize(40)
          Text('练习完成')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          Row() {
            this.resultTile('记得', this.remembered, Theme.MINT)
            this.resultTile('模糊', this.fuzzy, Theme.WARN)
            this.resultTile('忘了', this.forgotten, Theme.DANGER)
          }
          .width('100%')
          Text('用时 ' + Math.floor(this.elapsed / 60) + ' 分 ' + (this.elapsed % 60) + ' 秒')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)

          Text('再来一轮')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(46)
            .borderRadius(12)
            .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
            .onClick(() => {
              this.backToConfig()
            })
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      }
      }
        .width('100%')
      .margin({ top: 30 })
    }
    .layoutWeight(1)
  }

  @Builder
  resultTile(label: string, value: number, color: string) {
    Column({ space: 6 }) {
      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
    }
    .layoutWeight(1)
  }
}

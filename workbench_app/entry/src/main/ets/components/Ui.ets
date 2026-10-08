import { Theme } from '../common/Theme'

/**
 * 二级页面（NavDestination）统一的左右内边距。
 * 加在页面最外层内容 Column 上，PageHeader 与下方卡片因此始终对齐。
 */
export const PAGE_PAD_H: number = 16

/** 可滚动内容列的底部留白：列表最后一项不该贴着屏幕边缘 */
export const PAGE_SCROLL_BOTTOM: number = 64

/**
 * 半弹窗（bindSheet）内容区的上下留白。
 * dragBar 会占掉一部分顶部空间，所以标题需要显式的顶部内边距才不会贴住拖拽条。
 */
export const SHEET_PAD_TOP: number = 20
export const SHEET_PAD_BOTTOM: number = 18

/**
 * 科技风卡片容器：整卡点击走 onCard，不要在外层容器上挂 onClick（会被本组件的手势吃掉）。
 * clip 是按圆角裁的，paddingV 为 0 的整幅封面才不会把直角戳出卡片外。
 */
@Component
export struct TechCard {
  @BuilderParam content: () => void
  @Prop paddingV: number = 14
  @Prop radius: number = 18
  @Prop mt: number = 0
  @Prop mb: number = 0
  onCard: () => void = () => {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.paddingV)
    .borderRadius(this.radius)
    .clip(true)
    .linearGradient({
      angle: 180,
      colors: Theme.CARD_COLORS
    })
    .border({ width: 1, color: Theme.BORDER })
    .margin({ top: this.mt, bottom: this.mb })
    .onClick(() => {
      this.onCard()
    })
  }
}

/** 区块标题 */
@Component
export struct SectionTitle {
  @Prop title: string = ''
  @Prop accent: ResourceColor = Theme.CYAN

  build() {
    Row({ space: 8 }) {
      Column()
        .width(4)
        .height(16)
        .borderRadius(2)
        .backgroundColor(this.accent)
        .shadow({ radius: 6, color: '#6622D3EE', offsetY: 0 })
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
      Blank()
    }
    .width('100%')
    .margin({ bottom: 10 })
  }
}

/** 小号胶囊按钮：半弹窗标题栏与行内并列操作共用，等高 + 同最小宽度，两个并排时宽度一致 */
@Component
export struct PillButton {
  @Prop label: string = ''
  @Prop filled: boolean = true
  onTap: () => void = () => {
  }

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor(this.filled ? '#FFFFFF' : Theme.TEXT_SUB)
      .textAlign(TextAlign.Center)
      .height(32)
      .constraintSize({ minWidth: 64 })
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor(this.filled ? Theme.PRIMARY : Theme.INPUT_BG)
      .border({ width: 1, color: this.filled ? Theme.PRIMARY : Theme.BORDER })
      .onClick(() => {
        this.onTap()
      })
  }
}

/**
 * 半弹窗标题栏：标题左对齐，右侧最多两个并等操作（次要在左、主要右）。
 * 整行垂直居中，所以标题不会被右侧按钮的高度拽偏。
 */
@Component
export struct SheetHeader {
  @Prop title: string = ''
  @Prop actionLabel: string = ''
  @Prop actionLabel2: string = ''
  onAction: () => void = () => {
  }
  onAction2: () => void = () => {
  }

  build() {
    Row({ space: 8 }) {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.actionLabel2.length > 0) {
        PillButton({
          label: this.actionLabel2,
          filled: false,
          onTap: (): void => {
            this.onAction2()
          }
        })
      }
      if (this.actionLabel.length > 0) {
        PillButton({
          label: this.actionLabel,
          filled: true,
          onTap: (): void => {
            this.onAction()
          }
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

/** 半弹窗主提交按钮：整宽渐变，busy 时降透明度并吞掉点击 */
@Component
export struct SheetSubmit {
  @Prop label: string = '保 存'
  @Prop busy: boolean = false
  onSubmit: () => void = () => {
  }

  build() {
    Text(this.label)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(46)
      .borderRadius(12)
      .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
      .opacity(this.busy ? 0.6 : 1)
      .margin({ top: 20 })
      .onClick(() => {
        if (!this.busy) {
          this.onSubmit()
        }
      })
  }
}

/** 半弹窗删除入口：整宽，紧跟在主按钮之后 */
@Component
export struct SheetDelete {
  @Prop label: string = '删除'
  @Prop busy: boolean = false
  onDelete: () => void = () => {
  }

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor(Theme.DANGER)
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(44)
      .margin({ top: 4 })
      .onClick(() => {
        if (!this.busy) {
          this.onDelete()
        }
      })
  }
}

/** 圆角小标签 */
@Component
export struct Chip {  @Prop text: string = ''
  @Prop color: string = Theme.CYAN
  @Prop selected: boolean = false
  @Prop small: boolean = false

  build() {
    Text(this.text)
      .fontSize(this.small ? 11 : 12)
      .fontColor(this.selected ? '#FFFFFF' : this.color)
      .padding({ left: this.small ? 8 : 10, right: this.small ? 8 : 10, top: this.small ? 3 : 5, bottom: this.small ? 3 : 5 })
      .borderRadius(999)
      .backgroundColor(this.selected ? this.color : Theme.softOf(this.color, '22'))
      .border({
        width: 1,
        color: this.selected ? this.color : Theme.softOf(this.color, '55')
      })
  }
}

/** 可选中的横向筛选 chips */
@Component
export struct OptionChips {
  @Prop options: string[] = []
  @Prop labels: string[] = []
  @Prop selected: number = 0
  onSelect: (index: number) => void = () => {
  }

  labelOf(index: number): string {
    if (this.labels.length > index) {
      return this.labels[index]
    }
    return this.options[index]
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.options, (option: string, index: number) => {
          Chip({
            text: this.labelOf(index),
            selected: this.selected === index
          })
            .onClick(() => {
              this.onSelect(index)
            })
        }, (option: string) => option + this.selected.toString())
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}

/** 统计块（首页/概览用） */
@Component
export struct StatTile {
  @Prop icon: string = ''
  @Prop value: string = ''
  @Prop label: string = ''
  @Prop accent: string = Theme.CYAN
  @Prop weighted: boolean = false
  onTile: () => void = () => {
  }

  build() {
    Column({ space: 6 }) {
      Text(this.icon)
        .fontSize(18)
      Text(this.value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.label)
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
        .maxLines(1)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 6, right: 6 })
    .borderRadius(14)
    .backgroundColor(Theme.CARD_SOLID)
    .border({ width: 1, color: Theme.BORDER })
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(this.weighted ? 1 : 0)
    .onClick(() => {
      this.onTile()
    })
  }
}

/** 空状态 */
@Component
export struct EmptyView {
  @Prop icon: string = '🛰️'
  @Prop text: string = '这里空空如也'

  build() {
    Column({ space: 10 }) {
      Text(this.icon)
        .fontSize(40)
        .opacity(0.8)
      Text(this.text)
        .fontSize(13)
        .fontColor(Theme.TEXT_FAINT)
    }
    .width('100%')
    .padding({ top: 36, bottom: 36 })
    .alignItems(HorizontalAlign.Center)
  }
}

/** 功能页页头：返回 + 标题 + 右侧动作（顶部预留状态栏高度） */
@Component
export struct PageHeader {
  @Consume('nav') nav: NavPathStack
  @Consume('topInset') topInset: number
  @Prop title: string = ''
  @Prop actionLabel: string = ''
  onAction: () => void = () => {
  }

  build() {
    Row({ space: 12 }) {
      Text('‹')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor(Theme.CARD_SOLID)
        .border({ width: 1, color: Theme.BORDER })
        .onClick(() => {
          this.nav.pop()
        })
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.actionLabel.length > 0) {
        Text(this.actionLabel)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(12)
          .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
          .onClick(() => {
            this.onAction()
          })
      }
    }
    .width('100%')
    .height(52)
    .margin({ top: this.topInset })
  }
}

/** 只读星级 */
@Component
export struct Stars {
  @Prop rating: number = 0
  @Prop starSize: number = 12

  build() {
    Text(this.rating > 0 ? this.repeatStars() : '未评分')
      .fontSize(this.starSize)
      .fontColor(this.rating > 0 ? Theme.WARN : Theme.TEXT_FAINT)
  }

  private repeatStars(): string {
    let stars: string = ''
    const full = Math.round(this.rating)
    for (let i = 0; i < 5; i++) {
      stars += i < full ? '★' : '☆'
    }
    return stars
  }
}

/** 星级选择（编辑表单用） */
@Component
export struct StarPicker {
  @Prop value: number = 0
  onChange: (value: number) => void = () => {
  }

  build() {
    Row({ space: 10 }) {
      ForEach([1, 2, 3, 4, 5], (n: number) => {
        Text(n <= this.value ? '★' : '☆')
          .fontSize(26)
          .fontColor(n <= this.value ? Theme.WARN : Theme.TEXT_FAINT)
          .onClick(() => {
            this.onChange(n)
          })
      }, (n: number) => n.toString() + this.value.toString())
      if (this.value > 0) {
        Text('清除')
          .fontSize(12)
          .fontColor(Theme.TEXT_FAINT)
          .onClick(() => {
            this.onChange(0)
          })
      }
    }
  }
}

/** 迷你横向进度条 */
@Component
export struct MiniBar {
  @Prop ratio: number = 0
  @Prop color: string = Theme.CYAN

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height(6)
        .borderRadius(3)
        .backgroundColor(Theme.BORDER)
      Column()
        .width(this.ratio * 100 + '%')
        .height(6)
        .borderRadius(3)
        .linearGradient({ angle: 90, colors: Theme.MINT_COLORS })
    }
    .width('100%')
    .height(6)
  }
}

/** 表单输入行 */
@Component
export struct FieldLabel {
  @Prop label: string = ''

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor(Theme.TEXT_SUB)
      .margin({ top: 12, bottom: 6 })
  }
}

/** 页面背景（纯色，与状态栏/导航条区域无缝衔接） */
@Component
export struct TechBackground {
  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
  }
}

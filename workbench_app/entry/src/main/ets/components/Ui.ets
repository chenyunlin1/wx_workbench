import { Theme } from '../common/Theme'
import { AppColor, AppFont, AppRadius, AppSpace, HomeTheme } from '../theme/Theme'
import { WindowUtils } from '../utils/WindowUtils'

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
 * 卡片容器：模板风纯色卡（comp_background_primary + 大圆角），整卡点击走 onCard。
 * clip 是按圆角裁的，paddingV 为 0 的整幅封面才不会把直角戳出卡片外。
 */
@ComponentV2
export struct TechCard {
  @BuilderParam content: () => void
  @Param paddingV: number = 16
  @Param radius: number = AppRadius.Lg
  @Param mt: number = 0
  @Param mb: number = 0
  @Event onCard: () => void = () => {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.paddingV)
    .borderRadius(this.radius)
    .clip(true)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .margin({ top: this.mt, bottom: this.mb })
    .onClick(() => {
      this.onCard()
    })
  }
}

/** 区块标题 */
@ComponentV2
export struct SectionTitle {
  @Param title: string = ''
  @Param accent: ResourceColor = AppColor.Brand

  build() {
    Row({ space: AppSpace.Xs }) {
      Column()
        .width(3)
        .height(14)
        .borderRadius(2)
        .backgroundColor(this.accent)
      Text(this.title)
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Blank()
    }
    .width('100%')
    .margin({ bottom: AppSpace.Xs })
  }
}

/** 小号胶囊按钮：半弹窗标题栏与行内并列操作共用，等高 + 同最小宽度，两个并排时宽度一致 */
@ComponentV2
export struct PillButton {
  @Param label: string = ''
  @Param filled: boolean = true
  @Event onTap: () => void = () => {
  }

  build() {
    Text(this.label)
      .fontSize(AppFont.Caption + 1)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.filled ? AppColor.OnBrand : $r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .height(32)
      .constraintSize({ minWidth: 64 })
      .padding({ left: AppSpace.Sm, right: AppSpace.Sm })
      .borderRadius(AppRadius.Pill)
      .backgroundColor(this.filled ? AppColor.Brand : $r('sys.color.comp_background_tertiary'))
      .onClick(() => {
        this.onTap()
      })
  }
}

/**
 * 半弹窗标题栏：标题左对齐，右侧最多两个并等操作（次要在左、主要右）。
 * 整行垂直居中，所以标题不会被右侧按钮的高度拽偏。
 */
@ComponentV2
export struct SheetHeader {
  @Param title: string = ''
  @Param actionLabel: string = ''
  @Param actionLabel2: string = ''
  @Event onAction: () => void = () => {
  }
  @Event onAction2: () => void = () => {
  }

  build() {
    Row({ space: AppSpace.Xs }) {
      Text(this.title)
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
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
    // 半模态右上角有系统关闭按钮（showClose 默认 true，不在业务代码里），有右侧操作时为其预留占区
    .padding({ right: (this.actionLabel.length > 0 || this.actionLabel2.length > 0) ? 48 : 0 })
  }
}

/** 半弹窗主提交按钮：整宽品牌色胶囊，busy 时降透明度并吞掉点击 */
@ComponentV2
export struct SheetSubmit {
  @Param label: string = '保 存'
  @Param busy: boolean = false
  @Event onSubmit: () => void = () => {
  }

  build() {
    Text(this.label)
      .fontSize(AppFont.BodyL)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColor.OnBrand)
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(46)
      .borderRadius(AppRadius.Pill)
      .backgroundColor(AppColor.Brand)
      .opacity(this.busy ? 0.6 : 1)
      .margin({ top: AppSpace.Md })
      .onClick(() => {
        if (!this.busy) {
          this.onSubmit()
        }
      })
  }
}

/** 半弹窗删除入口：整宽，紧跟在主按钮之后 */
@ComponentV2
export struct SheetDelete {
  @Param label: string = '删除'
  @Param busy: boolean = false
  @Event onDelete: () => void = () => {
  }

  build() {
    Text(this.label)
      .fontSize(AppFont.Caption + 1)
      .fontColor(Theme.DANGER)
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(44)
      .margin({ top: AppSpace.Xxs })
      .onClick(() => {
        if (!this.busy) {
          this.onDelete()
        }
      })
  }
}

/** 圆角小标签：色值接受 hex 字符串或资源色，选中态实心填充 */
@ComponentV2
export struct Chip {
  @Param text: string = ''
  @Param color: ResourceColor = AppColor.Brand
  @Param selected: boolean = false
  @Param small: boolean = false

  private softFill(): ResourceColor {
    const c: ResourceColor = this.color
    if (typeof c === 'string' && c.length === 7 && c.startsWith('#')) {
      return Theme.softOf(c, '22')
    }
    return $r('sys.color.comp_background_tertiary')
  }

  private softStroke(): ResourceColor {
    const c: ResourceColor = this.color
    if (typeof c === 'string' && c.length === 7 && c.startsWith('#')) {
      return Theme.softOf(c, '55')
    }
    return Color.Transparent
  }

  build() {
    Text(this.text)
      .fontSize(this.small ? 11 : AppFont.Caption)
      .fontColor(this.selected ? '#FFFFFF' : this.color)
      .padding({
        left: this.small ? AppSpace.Xs : 10,
        right: this.small ? AppSpace.Xs : 10,
        top: this.small ? 3 : 5,
        bottom: this.small ? 3 : 5
      })
      .borderRadius(AppRadius.Pill)
      .backgroundColor(this.selected ? this.color : this.softFill())
      .border({ width: 1, color: this.selected ? this.color : this.softStroke() })
  }
}

/** 可选中的横向筛选 chips */
@ComponentV2
export struct OptionChips {
  @Param options: string[] = []
  @Param labels: string[] = []
  @Param selected: number = 0
  @Event onSelect: (index: number) => void = () => {
  }

  private labelOf(index: number): string {
    if (this.labels.length > index) {
      return this.labels[index]
    }
    return this.options[index]
  }

  build() {
    Scroll() {
      Row({ space: AppSpace.Xs }) {
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
@ComponentV2
export struct StatTile {
  @Param icon: string = ''
  @Param value: string = ''
  @Param label: string = ''
  @Param accent: ResourceColor = AppColor.Brand
  @Param weighted: boolean = false
  @Event onTile: () => void = () => {
  }

  build() {
    Column({ space: 6 }) {
      Text(this.icon)
        .fontSize(AppFont.Title)
      Text(this.value)
        .fontSize(AppFont.Title)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.label)
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .width('100%')
    .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm, left: 6, right: 6 })
    .borderRadius(AppRadius.Md)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(this.weighted ? 1 : 0)
    .onClick(() => {
      this.onTile()
    })
  }
}

/** 空状态 */
@ComponentV2
export struct EmptyView {
  @Param icon: string = '🛰️'
  @Param text: string = '这里空空如也'

  build() {
    Column({ space: AppSpace.Xs }) {
      Text(this.icon)
        .fontSize(40)
        .opacity(0.8)
      Text(this.text)
        .fontSize(AppFont.Caption + 1)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ top: 36, bottom: 36 })
    .alignItems(HorizontalAlign.Center)
  }
}

/** 功能页页头：返回 + 标题 + 右侧动作（顶部预留状态栏高度） */
@ComponentV2
export struct PageHeader {
  @Param navStack: NavPathStack = new NavPathStack()
  @Param title: string = ''
  @Param actionLabel: string = ''
  @Event onAction: () => void = () => {
  }

  build() {
    Row({ space: AppSpace.Xs }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([$r('sys.color.font_primary')])
        .onClick(() => {
          this.navStack.pop()
        })
      Text(this.title)
        .fontSize(AppFont.Title)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.actionLabel.length > 0) {
        Text(this.actionLabel)
          .fontSize(AppFont.Caption + 1)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.OnBrand)
          .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: 7, bottom: 7 })
          .borderRadius(AppRadius.Pill)
          .backgroundColor(AppColor.Brand)
          .onClick(() => {
            this.onAction()
          })
      }
    }
    .width('100%')
    .height(52)
    .margin({ top: WindowUtils.getStatusBarHeightVp() })
  }
}

/** 只读星级 */
@ComponentV2
export struct Stars {
  @Param rating: number = 0
  @Param starSize: number = 12

  private repeatStars(): string {
    let stars: string = ''
    const full = Math.round(this.rating)
    for (let i = 0; i < 5; i++) {
      stars += i < full ? '★' : '☆'
    }
    return stars
  }

  build() {
    Text(this.rating > 0 ? this.repeatStars() : '未评分')
      .fontSize(this.starSize)
      .fontColor(this.rating > 0 ? Theme.WARN : $r('sys.color.font_tertiary'))
  }
}

/** 星级选择（编辑表单用） */
@ComponentV2
export struct StarPicker {
  @Param value: number = 0
  @Event onChange: (value: number) => void = () => {
  }

  build() {
    Row({ space: 10 }) {
      ForEach([1, 2, 3, 4, 5], (n: number) => {
        Text(n <= this.value ? '★' : '☆')
          .fontSize(26)
          .fontColor(n <= this.value ? Theme.WARN : $r('sys.color.font_tertiary'))
          .onClick(() => {
            this.onChange(n)
          })
      }, (n: number) => n.toString() + this.value.toString())
      if (this.value > 0) {
        Text('清除')
          .fontSize(AppFont.Caption)
          .fontColor($r('sys.color.font_tertiary'))
          .onClick(() => {
            this.onChange(0)
          })
      }
    }
  }
}

/** 迷你横向进度条 */
@ComponentV2
export struct MiniBar {
  @Param ratio: number = 0
  @Param color: ResourceColor = AppColor.Brand

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height(6)
        .borderRadius(3)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
      Column()
        .width(this.ratio * 100 + '%')
        .height(6)
        .borderRadius(3)
        .backgroundColor(this.color)
    }
    .width('100%')
    .height(6)
  }
}

/** 表单输入行 */
@ComponentV2
export struct FieldLabel {
  @Param label: string = ''

  build() {
    Text(this.label)
      .fontSize(AppFont.Caption)
      .fontColor($r('sys.color.font_secondary'))
      .margin({ top: AppSpace.Sm, bottom: 6 })
  }
}

/** 页面背景（暖色渐变，与模板首页/我的页一致，随深浅色自动切换） */
@ComponentV2
export struct TechBackground {
  build() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [[HomeTheme.BgWarmTop, 0.0], [HomeTheme.BgWarmMid, 0.45], [HomeTheme.BgNeutral, 1.0]]
      })
  }
}

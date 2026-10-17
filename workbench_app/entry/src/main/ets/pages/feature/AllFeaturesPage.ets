import { AppFont, AppSpace } from '../../theme/Theme'
import { PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader } from '../../components/Ui'
import { FEATURE_ENTRIES, FeatureEntry } from '../../common/Features'

const TILE_GAP: number = 10

/** 全部功能页：首页「更多」进入，展示 FEATURE_ENTRIES 全量入口 */
@ComponentV2
export struct AllFeaturesPage {
  @Param nav: NavPathStack = new NavPathStack();

  build() {
    Scroll() {
      Column() {
        PageHeader({
          navStack: this.nav,
          title: '全部功能'
        })
        GridRow({ columns: 4, gutter: TILE_GAP }) {
          ForEach(FEATURE_ENTRIES, (entry: FeatureEntry) => {
            GridCol({ span: 1 }) {
              Column({ space: AppSpace.Xs }) {
                Text(entry.icon)
                  .fontSize(30)
                Text(entry.label)
                  .fontSize(11)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .onClick(() => {
                this.nav.pushPathByName(entry.target, null)
              })
            }
          }, (entry: FeatureEntry) => entry.target)
        }
        .width('100%')
        .margin({ top: AppSpace.Sm })
      }
      .width('100%')
      .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: PAGE_SCROLL_BOTTOM })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }
}

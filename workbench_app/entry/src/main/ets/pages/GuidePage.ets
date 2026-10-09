import { AppRadius, AppSpace, AppFont } from '../theme/Theme';
import { WindowUtils } from '../utils/WindowUtils';

class GuideItem {
  id: string = '';
  action: ResourceStr = '';
  desc: ResourceStr = '';

  constructor(id: string, action: ResourceStr, desc: ResourceStr) {
    this.id = id;
    this.action = action;
    this.desc = desc;
  }
}

class GuideGroup {
  id: string = '';
  title: ResourceStr = '';
  items: GuideItem[] = [];

  constructor(id: string, title: ResourceStr, items: GuideItem[]) {
    this.id = id;
    this.title = title;
    this.items = items;
  }
}

/** 使用说明内容:每一条都对应代码里真实存在的交互 */
const GUIDE_GROUPS: GuideGroup[] = [
  new GuideGroup('common', $r('app.string.guide_group_common'), [
    new GuideItem('tab-double-tap', $r('app.string.guide_common_top_action'),
      $r('app.string.guide_common_top_desc')),
  ]),
];

@ComponentV2
export struct GuidePage {
  @Param navStack: NavPathStack = new NavPathStack();

  @Builder
  groupCard(group: GuideGroup): void {
    Column({ space: AppSpace.Xs }) {
      Text(group.title)
        .fontSize(AppFont.Caption)
        .fontColor($r('sys.color.font_tertiary'))
        .margin({ left: AppSpace.Sm, bottom: AppSpace.Xs })

      Column() {
        ForEach(group.items, (item: GuideItem, idx: number) => {
          Column({ space: 2 }) {
            Text(item.action)
              .fontSize(AppFont.BodyL)
              .fontColor($r('sys.color.font_primary'))
              .fontWeight(FontWeight.Medium)
            Text(item.desc)
              .fontSize(AppFont.Body)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Md, bottom: AppSpace.Md })

          if (idx < group.items.length - 1) {
            Divider().color('#F0F0F0').margin({ left: AppSpace.Lg, right: AppSpace.Lg })
          }
        }, (item: GuideItem) => item.id)
      }
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(AppRadius.Lg)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('sys.color.font_primary')])
          .onClick(() => this.navStack.pop())
        Text($r('app.string.guide_title'))
          .fontSize(AppFont.Title)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
          .margin({ left: AppSpace.Sm })
      }
      .width('100%')
      .padding({
        top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm,
        left: AppSpace.Md, right: AppSpace.Md, bottom: AppSpace.Md
      })

      Scroll() {
        Column({ space: AppSpace.Lg }) {
          ForEach(GUIDE_GROUPS, (group: GuideGroup) => {
            this.groupCard(group)
          }, (group: GuideGroup) => group.id)
        }
        .width('100%')
        .padding({ left: AppSpace.Md, right: AppSpace.Md, top: AppSpace.Xs, bottom: AppSpace.Xl })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

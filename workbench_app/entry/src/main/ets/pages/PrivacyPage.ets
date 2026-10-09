import { AppSpace, AppFont } from '../theme/Theme';
import { WindowUtils } from '../utils/WindowUtils';

class PolicySection {
  id: string;
  title: ResourceStr;
  paragraphs: ResourceStr[];

  constructor(id: string, title: ResourceStr, paragraphs: ResourceStr[]) {
    this.id = id;
    this.title = title;
    this.paragraphs = paragraphs;
  }
}

/** 隐私政策:模板仅保留占位内容,发布前替换为应用的正式条款。 */
const POLICY_SECTIONS: PolicySection[] = [
  new PolicySection('placeholder', $r('app.string.privacy_placeholder_title'), [
    $r('app.string.privacy_placeholder_body')
  ])
];

@ComponentV2
export struct PrivacyPage {
  @Param navStack: NavPathStack = new NavPathStack();

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column({ space: AppSpace.Lg }) {
          ForEach(POLICY_SECTIONS, (sec: PolicySection) => {
            Column({ space: AppSpace.Sm }) {
              Text(sec.title)
                .fontSize(AppFont.BodyL)
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Bold)
                .width('100%')

              ForEach(sec.paragraphs, (p: ResourceStr) => {
                Text(p)
                  .fontSize(AppFont.Body)
                  .fontColor($r('sys.color.font_secondary'))
                  .lineHeight(22)
                  .width('100%')
              })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
          }, (sec: PolicySection) => sec.id)
        }
        .width('100%')
        .padding({ bottom: WindowUtils.getBottomSafeVp() + AppSpace.Xl })
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

  @Builder
  buildHeader() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([$r('sys.color.font_primary')])
        .onClick(() => this.navStack.pop())
      Text($r('app.string.privacy_title'))
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
  }
}

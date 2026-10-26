import { webview } from '@kit.ArkWeb';
import { toast, Fmt } from '../../common/AppKit';
import { Theme } from '../../common/Theme';
import { AppColor, AppFont, AppRadius, AppSpace } from '../../theme/Theme';
import { WindowUtils } from '../../utils/WindowUtils';
import { BrowserHistoryEntry, BrowserHistoryService } from '../../service/BrowserHistoryService';
import { EmptyView, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, SectionTitle, TechCard } from '../../components/Ui';

/** 起始页常用站点 */
class BrowserSite {
  icon: string = '';
  name: string = '';
  url: string = '';

  constructor(icon: string, name: string, url: string) {
    this.icon = icon;
    this.name = name;
    this.url = url;
  }
}

const START_SITES: BrowserSite[] = [
  new BrowserSite('🔍', '必应', 'https://www.bing.com'),
  new BrowserSite('📖', '百度百科', 'https://baike.baidu.com'),
  new BrowserSite('📘', 'MDN', 'https://developer.mozilla.org/zh-CN/'),
  new BrowserSite('🐙', 'GitHub', 'https://github.com'),
  new BrowserSite('💡', '知乎', 'https://www.zhihu.com'),
  new BrowserSite('⚙️', '掘金', 'https://juejin.cn'),
  new BrowserSite('🧩', '华为开发者', 'https://developer.huawei.com/consumer/cn/'),
  new BrowserSite('📺', 'B 站', 'https://www.bilibili.com')
];

/** 起始页默认地址（首次挂载 Web 时用它，用户一点即换） */
const HOME_URL: string = 'https://www.bing.com';
const BAR_HEIGHT: number = 52;
const HISTORY_SHOWN: number = 10;

/** 工具栏按钮：图标 + 文案，禁用态自动吞掉点击 */
@ComponentV2
struct BrowserToolButton {
  @Param icon: Resource = $r('sys.symbol.chevron_left');
  @Param label: string = '';
  @Param tint: ResourceColor = $r('sys.color.font_primary');
  @Param active: boolean = true;
  @Event onTap: () => void = () => {
  };

  build() {
    Column({ space: 2 }) {
      SymbolGlyph(this.icon)
        .fontSize(20)
        .fontColor([this.active ? this.tint : $r('sys.color.font_tertiary')])
      Text(this.label)
        .fontSize(10)
        .fontColor(this.active ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
  }
}

/**
 * 内置浏览器：地址栏（网址或搜索）+ ArkWeb 网页 + 起始页（常用站点 / 最近访问）。
 * 返回键先回退网页历史，退到底再回起始页，起始页上才退出本页。
 * 最近访问只落本地文件（BrowserHistoryService），不与服务器交互。
 */
@ComponentV2
export struct BrowserPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local addrText: string = '';
  @Local webTitle: string = '';
  @Local webUrl: string = '';
  @Local loadProgress: number = 0;
  @Local isLoading: boolean = false;
  @Local canBack: boolean = false;
  @Local canForward: boolean = false;
  @Local errorHint: string = '';
  @Local historyItems: BrowserHistoryEntry[] = [];
  @Local webMounted: boolean = false;
  @Local homeOn: boolean = true;
  @Local destTranslateX: string = '0%';
  private controller: webview.WebviewController = new webview.WebviewController();
  // Web 的 src 只在创建瞬间生效，之后的跳转一律走 controller.loadUrl
  private mountUrl: string = HOME_URL;

  aboutToAppear(): void {
    this.refreshHistory();
  }

  /** 打开地址：交给 Web 组件加载；首次调用时才创建 Web */
  go(raw: string): void {
    const target: string = BrowserHistoryService.toTargetUrl(raw);
    if (target.length === 0) {
      toast('请输入网址或搜索内容');
      return;
    }
    this.errorHint = '';
    this.homeOn = false;
    this.webUrl = target;
    this.webTitle = '';
    this.addrText = target;
    this.loadProgress = 0;
    this.isLoading = true;
    if (!this.webMounted) {
      this.mountUrl = target;
      this.webMounted = true;
    } else {
      this.loadUrlSafely(target);
    }
  }

  private loadUrlSafely(url: string): void {
    try {
      this.controller.loadUrl(url);
    } catch (err) {
      this.isLoading = false;
      this.errorHint = '网页尚未就绪，请稍后再试';
    }
  }

  private stepBack(): void {
    try {
      this.controller.backward();
    } catch (err) {
      this.canBack = false;
    }
    this.refreshNavState();
  }

  private stepForward(): void {
    try {
      this.controller.forward();
    } catch (err) {
      this.canForward = false;
    }
    this.refreshNavState();
  }

  private reloadPage(): void {
    if (!this.webMounted) {
      return;
    }
    this.errorHint = '';
    try {
      this.controller.refresh();
    } catch (err) {
      this.errorHint = '无法刷新，请重新输入地址';
    }
  }

  private stopLoad(): void {
    try {
      this.controller.stop();
    } catch (err) {
      // 停止失败无需提示，进度条自己会走完
    }
    this.isLoading = false;
  }

  private backHome(): void {
    this.homeOn = true;
    this.errorHint = '';
    this.addrText = '';
    this.isLoading = false;
    this.refreshHistory();
    this.refreshNavState();
  }

  /** controller 未 attach 时调用 accessBackward 会抛错，一律 try 包住 */
  private refreshNavState(): void {
    if (!this.webMounted) {
      this.canBack = false;
      this.canForward = false;
      return;
    }
    try {
      this.canBack = this.controller.accessBackward();
      this.canForward = this.controller.accessForward();
    } catch (err) {
      this.canBack = false;
      this.canForward = false;
    }
  }

  private refreshHistory(): void {
    const items: BrowserHistoryEntry[] = BrowserHistoryService.list();
    const shown: BrowserHistoryEntry[] = [];
    for (let i = 0; i < items.length && i < HISTORY_SHOWN; i++) {
      shown.push(items[i]);
    }
    // @Local 数组要换引用才会重渲染
    this.historyItems = shown;
  }

  private clearHistory(): void {
    BrowserHistoryService.clear();
    this.refreshHistory();
    toast('已清空最近访问');
  }

  private statusText(): string {
    if (this.homeOn) {
      return '起始页 · 输入网址或选择常用站点';
    }
    const name: string = this.webTitle.length > 0 ? this.webTitle : BrowserHistoryService.hostOf(this.webUrl);
    return name.length > 0 ? name : '空白页';
  }

  private timeLabel(ts: number): string {
    const d: Date = new Date(ts);
    const hm: string = Fmt.pad2(d.getHours()) + ':' + Fmt.pad2(d.getMinutes());
    const day: string = Fmt.date(d);
    return day === Fmt.today() ? hm : day.substring(5) + ' ' + hm;
  }

  build() {
    NavDestination() {
      Column() {
        this.addressBar()
        this.statusBar()
        if (this.errorHint.length > 0) {
          this.errorBanner()
        }
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.webMounted) {
            Web({ src: this.mountUrl, controller: this.controller })
              .width('100%')
              .height('100%')
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .fileAccess(false)
              .mixedMode(MixedMode.All)
              .zoomAccess(true)
              .metaViewport(true)
              .geolocationAccess(false)
              .onControllerAttached((): void => {
                this.refreshNavState();
              })
              .onPageBegin((event: OnPageBeginEvent): void => {
                this.webUrl = event.url;
                this.addrText = event.url;
                this.homeOn = false;
                this.isLoading = true;
                this.loadProgress = 0;
                this.errorHint = '';
                this.refreshNavState();
              })
              .onPageEnd((event: OnPageEndEvent): void => {
                this.webUrl = event.url;
                this.addrText = event.url;
                this.isLoading = false;
                this.loadProgress = 100;
                BrowserHistoryService.push(event.url, this.webTitle);
                this.refreshHistory();
                this.refreshNavState();
              })
              .onTitleReceive((event: OnTitleReceiveEvent): void => {
                this.webTitle = event.title;
              })
              .onProgressChange((event: OnProgressChangeEvent): void => {
                this.loadProgress = event.newProgress;
              })
              .onErrorReceive((event: OnErrorReceiveEvent): void => {
                // 子资源（图片、脚本）失败很常见，只有主文档打不开才打扰用户
                if (event.request.isMainFrame()) {
                  this.isLoading = false;
                  this.errorHint = event.error.getErrorInfo();
                }
              })
            // 不做 onLoadIntercept：所有站点/协议一律放行，页内跳转与外部链接交给 WebView 自行处理
          }
          if (this.homeOn) {
            this.startView()
          }
        }
        .width('100%')
        .layoutWeight(1)
        this.browserToolbar()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_primary'))
    .onBackPressed((): boolean => {
      if (this.homeOn) {
        return false;
      }
      if (this.canBack) {
        this.stepBack();
        return true;
      }
      // 网页历史退完了：先回起始页，再按返回才真正离开本页
      this.backHome();
      return true;
    })
    .translate({ x: this.destTranslateX })
    .customTransition((operation: NavigationOperation, isEnter: boolean): Array<NavDestinationTransition> => {
      const enteringFromRight = operation !== NavigationOperation.POP && isEnter;
      const exitingToRight = operation === NavigationOperation.POP && !isEnter;
      this.destTranslateX = enteringFromRight ? '100%' : '0%';
      return [{
        duration: WindowUtils.getPageTransitionDuration(),
        curve: Curve.EaseInOut,
        event: () => {
          this.destTranslateX = exitingToRight ? '100%' : '0%';
        }
      }];
    })
  }

  @Builder
  addressBar() {
    Row({ space: AppSpace.Xs }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(22)
        .fontColor([$r('sys.color.font_primary')])
        .onClick(() => {
          this.nav.pop();
        })
      TextInput({ text: this.addrText, placeholder: '输入网址或搜索' })
        .layoutWeight(1)
        .height(36)
        .fontSize(AppFont.Body)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_tertiary'))
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(AppRadius.Pill)
        .border({ width: 1, color: AppColor.Divider })
        .padding({ left: AppSpace.Sm, right: AppSpace.Xxs })
        .maxLines(1)
        .onChange((value: string): void => {
          this.addrText = value;
        })
        .onSubmit((): void => {
          this.go(this.addrText);
        })
      if (this.addrText.length > 0) {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
          .onClick(() => {
            this.addrText = '';
          })
      }
      Text('前往')
        .fontSize(AppFont.Caption + 1)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.OnBrand)
        .height(32)
        .padding({ left: AppSpace.Sm, right: AppSpace.Sm })
        .borderRadius(AppRadius.Pill)
        .backgroundColor(AppColor.Brand)
        .onClick(() => {
          this.go(this.addrText);
        })
    }
    .width('100%')
    .height(BAR_HEIGHT)
    .margin({ top: WindowUtils.getStatusBarHeightVp() })
    .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H })
  }

  @Builder
  statusBar() {
    Column() {
      Row({ space: AppSpace.Xxs }) {
        SymbolGlyph(this.homeOn ? $r('sys.symbol.magnifyingglass')
          : (this.webUrl.startsWith('https://') ? $r('sys.symbol.lock_fill') : $r('sys.symbol.exclamationmark_circle')))
          .fontSize(12)
          .fontColor([this.homeOn ? $r('sys.color.font_tertiary')
            : (this.webUrl.startsWith('https://') ? AppColor.Brand : Theme.WARN)])
        Text(this.statusText())
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.isLoading) {
          Text(this.loadProgress.toString() + '%')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .width('100%')
      .height(20)
      .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H })

      Progress({ value: this.isLoading ? this.loadProgress : 0, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(3)
        .color(AppColor.Brand)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
    }
    .width('100%')
  }

  @Builder
  errorBanner() {
    Row({ space: AppSpace.Xxs }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(15)
        .fontColor([Theme.DANGER])
      Text('无法打开页面：' + this.errorHint)
        .fontSize(AppFont.Caption)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('重试')
        .fontSize(AppFont.Caption)
        .fontColor(AppColor.Brand)
        .onClick(() => {
          this.reloadPage();
        })
    }
    .width('100%')
    .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, top: AppSpace.Xxs, bottom: AppSpace.Xxs })
    .backgroundColor(Theme.DANGER_SOFT)
  }

  // 命名注意：不能叫 toolbar，与 CustomComponent 的属性方法同名会编译报错
  @Builder
  browserToolbar() {
    Row() {
      BrowserToolButton({
        icon: $r('sys.symbol.chevron_left'),
        label: '后退',
        active: this.webMounted && this.canBack,
        onTap: (): void => {
          this.stepBack();
        }
      })
      BrowserToolButton({
        icon: $r('sys.symbol.chevron_right'),
        label: '前进',
        active: this.webMounted && this.canForward,
        onTap: (): void => {
          this.stepForward();
        }
      })
      BrowserToolButton({
        icon: this.isLoading ? $r('sys.symbol.xmark_circle_fill') : $r('sys.symbol.arrow_clockwise'),
        label: this.isLoading ? '停止' : '刷新',
        tint: this.isLoading ? Theme.WARN : $r('sys.color.font_primary'),
        active: this.webMounted,
        onTap: (): void => {
          if (this.isLoading) {
            this.stopLoad();
          } else {
            this.reloadPage();
          }
        }
      })
      BrowserToolButton({
        icon: $r('sys.symbol.house_fill'),
        label: '起始页',
        active: this.webMounted && !this.homeOn,
        onTap: (): void => {
          this.backHome();
        }
      })
    }
    .width('100%')
    .height(BAR_HEIGHT + WindowUtils.getBottomSafeVp())
    .padding({ bottom: WindowUtils.getBottomSafeVp() })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 1 }, color: AppColor.Divider })
  }

  @Builder
  startView() {
    Scroll() {
      Column({ space: AppSpace.Xs }) {
        Text('🌐 内置浏览器')
          .fontSize(AppFont.Title)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .margin({ top: AppSpace.Xs })
        Text('地址栏输入网址直接打开，输入关键词则用必应搜索。')
          .fontSize(AppFont.Caption)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')

        SectionTitle({ title: '常用站点' })
        GridRow({ columns: 4, gutter: 10 }) {
          ForEach(START_SITES, (site: BrowserSite) => {
            GridCol({ span: 1 }) {
              Column({ space: AppSpace.Xxs }) {
                Text(site.icon)
                  .fontSize(22)
                Text(site.name)
                  .fontSize(11)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ top: AppSpace.Sm, bottom: AppSpace.Sm })
              .borderRadius(AppRadius.Md)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onClick(() => {
                this.go(site.url);
              })
            }
          }, (site: BrowserSite) => site.url)
        }
        .width('100%')
        .margin({ top: AppSpace.Xxs })

        SectionTitle({
          title: '最近访问',
          actionLabel: this.historyItems.length > 0 ? '清空' : '',
          onAction: (): void => {
            this.clearHistory();
          }
        })
        TechCard({ paddingV: this.historyItems.length > 0 ? 4 : 0 }) {
          if (this.historyItems.length === 0) {
            EmptyView({ icon: '🧭', text: '还没有访问记录' })
          } else {
            Column() {
              ForEach(this.historyItems, (item: BrowserHistoryEntry, index: number) => {
                Row({ space: AppSpace.Xs }) {
                  Column({ space: 2 }) {
                    Text(item.title)
                      .fontSize(AppFont.Body)
                      .fontColor($r('sys.color.font_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: AppSpace.Xxs }) {
                      Text(BrowserHistoryService.hostOf(item.url))
                        .fontSize(11)
                        .fontColor($r('sys.color.font_tertiary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(this.timeLabel(item.ts))
                        .fontSize(11)
                        .fontColor($r('sys.color.font_tertiary'))
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(16)
                    .fontColor([$r('sys.color.font_tertiary')])
                }
                .width('100%')
                .padding({
                  top: AppSpace.Sm,
                  bottom: AppSpace.Sm,
                  left: AppSpace.Sm,
                  right: AppSpace.Sm
                })
                .border({
                  width: { bottom: index === this.historyItems.length - 1 ? 0 : 1 },
                  color: AppColor.Divider
                })
                .onClick(() => {
                  this.go(item.url);
                })
              }, (item: BrowserHistoryEntry) => item.url)
            }
            .width('100%')
          }
        }

        Text('最近访问只保存在本机，按账号隔离，可在上方「清空」一次抹掉。')
          .fontSize(AppFont.Caption)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .margin({ top: AppSpace.Xs })
      }
      .width('100%')
      .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, top: AppSpace.Sm, bottom: PAGE_SCROLL_BOTTOM })
      // Scroll 内容矮于视口时默认垂直居中，撑满最小高度才能让起始页顶对齐
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}

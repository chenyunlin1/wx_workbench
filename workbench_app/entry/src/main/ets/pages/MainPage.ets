import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { HdsCompat, CompatibleTabsModifier } from '../utils/HdsCompat';
import { PlatformCompat } from '../utils/PlatformCompat';
import { WindowUtils } from '../utils/WindowUtils';
import { AppColor, HomeTheme } from '../theme/Theme';
import { PreferenceService } from '../service/PreferenceService';
import { HomeTab } from './tabs/HomeTab';
import { NotesTab } from './tabs/NotesTab';
import { LearningTab } from './tabs/LearningTab';
import { AiTab } from './tabs/AiTab';
import { ProfilePage } from './ProfilePage';

const FLOATING_BOTTOM: number = 4;
const FLOATING_MIN_SAFE_BOTTOM: number = 8;
const TAB_COUNT: number = 5;

@ComponentV2
export struct MainPage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Local currentTab: number = 0;
  @Local viewportWidth: number = 0;
  @Local bottomSafeVp: number = WindowUtils.getBottomSafeVp();

  private tabController: HdsTabsController = new HdsTabsController();
  /** 各 Tab 页的滚动控制器，用于双击 Tab 回顶部 */
  private scrollers: Map<number, Scroller> = new Map();
  /** 上一次 Tab 点击时间，用于双击检测 */
  private lastTabClickTime: number = 0;
  private lastTabClickIndex: number = -1;
  private safeAreaChangeHandler: (topVp: number, bottomVp: number) => void =
    (_topVp: number, bottomVp: number): void => {
      if (Math.abs(this.bottomSafeVp - bottomVp) < 0.1) return;
      this.bottomSafeVp = bottomVp;
    };

  aboutToAppear(): void {
    WindowUtils.setStatusBarLight(false);
    WindowUtils.addSafeAreaListener(this.safeAreaChangeHandler);
    WindowUtils.refreshAvoidArea();
    this.restoreDefaultTab();
  }

  aboutToDisappear(): void {
    WindowUtils.removeSafeAreaListener(this.safeAreaChangeHandler);
  }

  private handleViewportSizeChange(newValue: SizeOptions): void {
    if (typeof newValue.width !== 'number') return;
    const width: number = newValue.width;
    if (Math.abs(width - this.viewportWidth) < 1) return;
    this.viewportWidth = width;
  }

  private async restoreDefaultTab(): Promise<void> {
    const idx = await PreferenceService.getDefaultTab();
    if (idx <= 0 || idx >= TAB_COUNT) return;
    setTimeout(() => {
      this.changeTab(idx);
    }, 50);
  }

  /** 统一切 Tab 入口，让默认页恢复和页面内跳转都走 HdsTabs 原生切换。 */
  private changeTab(index: number): void {
    if (index < 0 || index >= TAB_COUNT || index === this.currentTab) return;
    this.tabController.changeIndex(index);
  }

  private buildTabBar(icon: Resource, label: ResourceStr): BottomTabBarStyle {
    return new BottomTabBarStyle(
      {
        normal: new SymbolGlyphModifier(icon).fontColor([$r('sys.color.font_primary')]).fontSize(24),
        selected: new SymbolGlyphModifier(icon).fontColor([AppColor.Brand]).fontSize(26)
      },
      label
    ).labelStyle({
      unselectedColor: $r('sys.color.font_primary'),
      selectedColor: AppColor.Brand
    });
  }

  private floatingBarStyle(): HdsTabsFloatingStyle | undefined {
    if (!PlatformCompat.floatingTabs) return undefined;
    return {
      // 宽窗口保留底部导航习惯，避免页签横跨整块屏幕。
      barSideMargin: Math.max(16, (this.viewportWidth - 720) / 2),
      barBottomMargin: Math.max(this.bottomSafeVp, FLOATING_MIN_SAFE_BOTTOM) + FLOATING_BOTTOM,
      gradientMask: { maskColor: $r('app.color.floating_bar_mask'), maskHeight: 92 },
      systemMaterialEffect: HdsCompat.adaptiveMaterial,
      // 保留随主题色变化的沉浸光感。
      lightColor: AppColor.Brand,
      // 智感握持：左右手自动跟手
      adaptToHandedness: true
    };
  }

  build() {
    HdsTabs({ controller: this.tabController }) {
      TabContent() {
        HomeTab({
          nav: this.navStack,
          onScrollerReady: (scroller: Scroller): void => { this.scrollers.set(0, scroller); }
        })
      }
      .tabBar(this.buildTabBar($r('sys.symbol.house_fill'), $r('app.string.tab_home')))

      TabContent() {
        NotesTab({
          nav: this.navStack,
          onScrollerReady: (scroller: Scroller): void => { this.scrollers.set(1, scroller); }
        })
      }
      .tabBar(this.buildTabBar($r('sys.symbol.bookmark_fill'), $r('app.string.tab_notes')))

      TabContent() {
        LearningTab({
          nav: this.navStack,
          onScrollerReady: (scroller: Scroller): void => { this.scrollers.set(2, scroller); }
        })
      }
      .tabBar(this.buildTabBar($r('sys.symbol.graduationcap_fill'), $r('app.string.tab_learning')))

      TabContent() {
        AiTab({
          onScrollerReady: (scroller: Scroller): void => { this.scrollers.set(3, scroller); }
        })
      }
      .tabBar(this.buildTabBar($r('sys.symbol.message_fill'), $r('app.string.tab_ai')))

      TabContent() {
        ProfilePage({
          navStack: this.navStack,
          onScrollerReady: (scroller: Scroller): void => { this.scrollers.set(4, scroller); }
        })
      }
      .tabBar(this.buildTabBar($r('sys.symbol.person_fill'), $r('app.string.tab_profile')))
    }
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    .attributeModifier(new CompatibleTabsModifier(this.floatingBarStyle(), 56 + this.bottomSafeVp))
    .onTabBarClick((index: number) => {
      const now = Date.now();
      const DOUBLE_TAP_DELAY = 300;
      if (index === this.lastTabClickIndex && (now - this.lastTabClickTime) < DOUBLE_TAP_DELAY) {
        // 双击当前 Tab → 滚动回顶部
        const scroller = this.scrollers.get(index);
        if (scroller) {
          try { scroller.scrollEdge(Edge.Top); } catch (_e) { /* ignore */ }
        }
      }
      this.lastTabClickTime = now;
      this.lastTabClickIndex = index;
    })
    .onChange((index: number) => {
      this.currentTab = index;
    })
    .animationDuration(300)
    .width('100%')
    .height('100%')
    .backgroundColor(HomeTheme.BgNeutral)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onSizeChange((_oldValue: SizeOptions, newValue: SizeOptions) => {
      this.handleViewportSizeChange(newValue);
    })
  }
}

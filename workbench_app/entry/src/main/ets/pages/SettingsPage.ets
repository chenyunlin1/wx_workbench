import { ConfigurationConstant } from '@kit.AbilityKit';
import { AppRadius, AppSpace, AppFont } from '../theme/Theme';
import { PreferenceService } from '../service/PreferenceService';
import { WindowUtils } from '../utils/WindowUtils';
import { AdaptiveLayout } from '../utils/AdaptiveLayout';
import { AppearanceSettingsComponent } from '../components/AppearanceSettingsComponent';
import { ImmersiveOptionTabs } from '../components/ImmersiveOptionTabs';

class ThemeOption {
  mode: number;
  label: Resource;

  constructor(mode: number, label: Resource) {
    this.mode = mode;
    this.label = label;
  }
}

class TabOption {
  idx: number;
  label: Resource;

  constructor(idx: number, label: Resource) {
    this.idx = idx;
    this.label = label;
  }
}

const THEME_OPTIONS: ThemeOption[] = [
  new ThemeOption(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET, $r('app.string.settings_theme_follow_system')),
  new ThemeOption(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT, $r('app.string.settings_theme_light')),
  new ThemeOption(ConfigurationConstant.ColorMode.COLOR_MODE_DARK, $r('app.string.settings_theme_dark'))
];

/** 默认打开的页签：与 MainPage 的五个页签一一对应。 */
const TAB_OPTIONS: TabOption[] = [
  new TabOption(0, $r('app.string.tab_home')),
  new TabOption(1, $r('app.string.tab_notes')),
  new TabOption(2, $r('app.string.tab_learning')),
  new TabOption(3, $r('app.string.tab_ai')),
  new TabOption(4, $r('app.string.tab_profile'))
];

const ROW_INDENT: number = AppSpace.Md;

@ComponentV2
export struct SettingsPage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Local currentMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @Local selectedThemeIndex: number = 0;
  @Local defaultTab: number = 0;
  @Local isLoaded: boolean = false;
  @Local viewportWidth: number = 0;
  @Local viewportHeight: number = 0;
  private viewportUpdateTimerId: number = -1;

  aboutToAppear(): void {
    this.loadPrefs();
  }

  aboutToDisappear(): void {
    this.cancelViewportUpdateTimer();
  }

  private cancelViewportUpdateTimer(): void {
    if (this.viewportUpdateTimerId !== -1) {
      clearTimeout(this.viewportUpdateTimerId);
      this.viewportUpdateTimerId = -1;
    }
  }

  private handleViewportSizeChange(newValue: SizeOptions): void {
    if (typeof newValue.width !== 'number' || typeof newValue.height !== 'number') return;
    const width: number = newValue.width;
    const height: number = newValue.height;
    if (Math.abs(width - this.viewportWidth) < 1 && Math.abs(height - this.viewportHeight) < 1) return;
    this.cancelViewportUpdateTimer();
    this.viewportUpdateTimerId = setTimeout(() => {
      this.viewportUpdateTimerId = -1;
      this.viewportWidth = width;
      this.viewportHeight = height;
    }, 0);
  }

  private isCompactLayout(): boolean {
    return AdaptiveLayout.isCompact(this.viewportWidth, this.viewportHeight);
  }

  private horizontalPadding(): number {
    return AdaptiveLayout.isCompact(this.viewportWidth, this.viewportHeight) ? AppSpace.Sm : AppSpace.Md;
  }

  private async loadPrefs(): Promise<void> {
    this.currentMode = await PreferenceService.getColorMode();
    this.selectedThemeIndex = THEME_OPTIONS.findIndex((opt: ThemeOption) => opt.mode === this.currentMode);
    if (this.selectedThemeIndex === -1) {
      this.selectedThemeIndex = 0;
    }
    this.defaultTab = await PreferenceService.getDefaultTab();
    this.isLoaded = true;
  }

  private async setDefaultTab(idx: number): Promise<void> {
    this.defaultTab = idx;
    await PreferenceService.setDefaultTab(idx);
  }

  private async setColorMode(mode: number): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      ctx?.getApplicationContext().setColorMode(mode);
    } catch (_e) { /* system API may throw on invalid context */ }
    this.currentMode = mode;
    const newIndex = THEME_OPTIONS.findIndex((opt: ThemeOption) => opt.mode === mode);
    this.selectedThemeIndex = newIndex !== -1 ? newIndex : 0;
    await PreferenceService.setColorMode(mode);

    // 延迟更新状态栏，让主题切换完成后再应用
    setTimeout(() => {
      WindowUtils.updateColorMode(mode);
    }, 100);
  }

  build() {
    Column() {
      this.buildHeader()

      if (this.isLoaded) {
        Scroll() {
          GridRow({ columns: this.viewportWidth >= AdaptiveLayout.LARGE_WIDTH ? 2 : 1,
            gutter: AdaptiveLayout.sectionSpacing(this.viewportWidth, this.viewportHeight) }) {
            GridCol() { this.buildAppearanceGroup() }
            GridCol() { this.buildLaunchGroup() }
          }
          .width('100%')
          .padding({
            left: this.horizontalPadding(),
            right: this.horizontalPadding(),
            top: this.isCompactLayout() ? 0 : AppSpace.Sm,
            bottom: AppSpace.Xl
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onSizeChange((_oldValue: SizeOptions, newValue: SizeOptions) => {
      this.handleViewportSizeChange(newValue);
    })
  }

  @Builder
  buildHeader() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([$r('sys.color.font_primary')])
        .onClick(() => this.navStack.pop())
      Text($r('app.string.settings_title'))
        .fontSize(AppFont.TitleL)
        .fontColor($r('sys.color.font_primary'))
        .fontWeight(FontWeight.Bold)
        .margin({ left: AppSpace.Sm })
    }
    .width('100%')
    .padding({
      top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm,
      left: AppSpace.Md,
      right: AppSpace.Md,
      bottom: this.isCompactLayout() ? AppSpace.Sm : AppSpace.Md
    })
  }

  @Builder
  buildGroupTitle(title: ResourceStr) {
    Text(title)
      .fontSize(AppFont.Body)
      .fontColor($r('sys.color.font_tertiary'))
      .padding({ left: AppSpace.Sm, bottom: AppSpace.Xs })
  }

  @Builder
  buildDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: ROW_INDENT })
  }

  @Builder
  buildAppearanceGroup() {
    Column() {
      this.buildGroupTitle($r('app.string.settings_group_appearance'))

      Column() {
        Row({ space: AppSpace.Sm }) {
          Column({ space: 2 }) {
            Text($r('app.string.settings_theme_mode'))
              .fontSize(AppFont.BodyL)
              .fontColor($r('sys.color.font_primary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          ImmersiveOptionTabs({
            labels: THEME_OPTIONS.map((opt: ThemeOption): ResourceStr => opt.label),
            selected: this.selectedThemeIndex,
            onSelect: (index: number): void => { this.setColorMode(THEME_OPTIONS[index].mode); }
          })

        }
        .width('100%')
        .padding({
          left: ROW_INDENT,
          right: AppSpace.Xs,
          top: AppSpace.Sm,
          bottom: AppSpace.Sm
        })
        .constraintSize({ minHeight: 56 })

        AppearanceSettingsComponent()
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(AppRadius.Lg)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildLaunchGroup() {
    Column() {
      this.buildGroupTitle($r('app.string.settings_group_launch'))

      Column() {
        this.buildSelectItem(
          $r('app.string.settings_default_tab'),
          TAB_OPTIONS.map((opt: TabOption): SelectOption => { return { value: opt.label }; }),
          this.defaultTab,
          (index: number) => this.setDefaultTab(index)
        )
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(AppRadius.Lg)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSelectItem(
    title: ResourceStr,
    options: SelectOption[],
    selected: number,
    onSelect: (index: number) => void
  ) {
    Row({ space: AppSpace.Sm }) {
      Column({ space: 2 }) {
        Text(title).fontSize(AppFont.BodyL).fontColor($r('sys.color.font_primary')).width('100%')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      ImmersiveOptionTabs({
        labels: options.map((option: SelectOption): ResourceStr => option.value),
        selected: selected,
        onSelect: (index: number): void => onSelect(index)
      })
    }
    .width('100%').padding(ROW_INDENT)
  }
}

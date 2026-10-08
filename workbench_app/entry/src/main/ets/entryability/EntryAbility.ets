import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { Session } from '../store/Session';
import { Theme } from '../common/Theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 初始化会话：加载 Token / 用户 / 服务器地址
    Session.init(this.context);
    // 探测系统深浅色模式（通过 base/dark 资源探针取值）
    this.detectColorMode();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    this.setupImmersiveWindow(windowStage);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 系统深浅色切换：更新主题缓存、窗口背景与系统栏颜色
    this.detectColorMode();
    this.applySystemBarTheme();
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  /**
   * 探测当前深浅色：app.color.theme_probe 在 base 中是 #000001、dark 中是 #000002。
   */
  private async detectColorMode(): Promise<void> {
    try {
      const probe = await this.context.resourceManager.getColorByName('theme_probe');
      const mode = probe === 2 ? 'dark' : 'light';
      AppStorage.setOrCreate('colorMode', mode);
      hilog.info(DOMAIN, 'testTag', 'Color mode detected: %{public}s', mode);
    } catch (err) {
      AppStorage.setOrCreate('colorMode', 'dark');
      hilog.error(DOMAIN, 'testTag', 'Failed to detect color mode: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 沉浸式全屏：布局延伸到状态栏 / 导航条之下，
   * 窗口背景与页面背景同为 Theme.BG（纯色无缝），内容按避让高度下移。
   */
  private setupImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const win = windowStage.getMainWindowSync();
      this.mainWindow = win;
      win.setWindowLayoutFullScreen(true);

      const density = display.getDefaultDisplaySync().densityPixels;
      const statusBar = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navIndicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('statusBarHeight', Math.ceil(statusBar.topRect.height / density));
      AppStorage.setOrCreate('navBarHeight', Math.ceil(navIndicator.bottomRect.height / density));

      this.applySystemBarTheme();
      hilog.info(DOMAIN, 'testTag', 'Immersive window ready. statusBar=%{public}d navBar=%{public}d',
        AppStorage.get<number>('statusBarHeight') ?? 0, AppStorage.get<number>('navBarHeight') ?? 0);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to setup immersive window: %{public}s', JSON.stringify(err));
    }
  }

  private applySystemBarTheme(): void {
    if (this.mainWindow === null) {
      return;
    }
    try {
      const contentColor = Theme.isDark() ? '#FFFFFF' : '#17233B';
      this.mainWindow.setWindowSystemBarProperties({
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      });
      this.mainWindow.setWindowBackgroundColor(Theme.BG);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply system bar theme: %{public}s', JSON.stringify(err));
    }
  }
}

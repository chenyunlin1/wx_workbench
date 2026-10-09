import { ConfigurationConstant, Configuration, UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { WindowUtils } from '../utils/WindowUtils';
import { PreferenceService } from '../service/PreferenceService';
import { Session } from '../store/Session';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    // 会话（Token / 用户 / 服务器地址）必须在首屏渲染前就绪
    Session.init(this.context);
    this.syncColorMode(this.context.config.colorMode);
    // 偏好库必须早于首页读取：恢复上次保存的深浅色模式。
    PreferenceService.init(this.context)
      .then((): Promise<void> => this.restoreColorMode())
      .catch((err: Error): void => {
        hilog.error(DOMAIN, TAG, 'Preference init failed: %{public}s', err?.message ?? JSON.stringify(err));
      });
  }

  private async restoreColorMode(): Promise<void> {
    const mode = await PreferenceService.getColorMode();
    if (mode !== ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      try {
        this.context.getApplicationContext().setColorMode(mode);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Restore colorMode failed: %{public}s', JSON.stringify(err));
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.loadMainWindow(windowStage).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Main window load failed: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    this.loadMainWindow(windowStage).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Restored window load failed: %{public}s', JSON.stringify(err));
    });
  }

  private async loadMainWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      await WindowUtils.setupImmersive(windowStage, this.context.config.colorMode);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Immersive setup failed: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      WindowUtils.refreshAvoidArea();
    });
  }

  /** 系统深浅色切换时，同步状态栏字色，避免深色模式下黑字看不见 */
  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig.colorMode !== undefined) {
      this.syncColorMode(newConfig.colorMode);
      WindowUtils.updateColorMode(newConfig.colorMode);
    }
  }

  onWindowStageDestroy(): void {
    WindowUtils.releaseWindow();
  }

  /** 兼容层 Theme.isDark() 依赖此键；同时业务页的深浅色手写色值也用它分档 */
  private syncColorMode(mode: ConfigurationConstant.ColorMode | undefined): void {
    const isDark: boolean = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate<string>('colorMode', isDark ? 'dark' : 'light');
  }
}

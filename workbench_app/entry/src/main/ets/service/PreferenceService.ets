import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppAppearance } from '../model/AppAppearance';

/** 设置持久化：深浅色 / 材质 / 主题色 / 默认打开的 Tab */
const STORE_NAME = 'app_prefs';
const KEY_COLOR_MODE = 'color_mode';
const KEY_MATERIAL_STYLE = 'material_style';
const KEY_ACCENT_COLOR = 'accent_color';
const KEY_DEFAULT_TAB = 'default_tab';
const TAB_COUNT = 4;

export class PreferenceService {
  private static store: preferences.Preferences | null = null;
  private static initPromise: Promise<void> | null = null;

  /** 由 EntryAbility 启动时调用；同时把外观偏好灌入 AppAppearance 单例。 */
  static async init(context: common.BaseContext): Promise<void> {
    if (PreferenceService.store) {
      return;
    }
    if (!PreferenceService.initPromise) {
      const options: preferences.Options = { name: STORE_NAME };
      PreferenceService.initPromise = preferences.getPreferences(context, options).then(async (s) => {
        PreferenceService.store = s;
        const material = await s.get(KEY_MATERIAL_STYLE, 0);
        const accent = await s.get(KEY_ACCENT_COLOR, '');
        AppAppearance.current.material = AppAppearance.normalizeMaterial(typeof material === 'number' ? material : 0);
        AppAppearance.current.accent = AppAppearance.normalizeAccent(typeof accent === 'string' ? accent : '');
      });
    }
    await PreferenceService.initPromise;
  }

  private static async ensureStore(): Promise<preferences.Preferences> {
    if (!PreferenceService.store) {
      if (PreferenceService.initPromise) {
        await PreferenceService.initPromise;
      }
      if (!PreferenceService.store) {
        throw new Error('PreferenceService not initialized');
      }
    }
    return PreferenceService.store;
  }

  static async getColorMode(): Promise<number> {
    const s = await PreferenceService.ensureStore();
    const value = await s.get(KEY_COLOR_MODE, ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    return typeof value === 'number' ? value : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  static async setColorMode(mode: number): Promise<void> {
    const s = await PreferenceService.ensureStore();
    await s.put(KEY_COLOR_MODE, mode);
    await s.flush();
  }

  static async setMaterialStyle(value: number): Promise<void> {
    const material: number = AppAppearance.normalizeMaterial(value);
    const s = await PreferenceService.ensureStore();
    await s.put(KEY_MATERIAL_STYLE, material);
    await s.flush();
    AppAppearance.current.material = material;
  }

  static async setAccentColor(value: string): Promise<void> {
    const accent: string = AppAppearance.normalizeAccent(value);
    const s = await PreferenceService.ensureStore();
    await s.put(KEY_ACCENT_COLOR, accent);
    await s.flush();
    AppAppearance.current.accent = accent;
  }

  static async getDefaultTab(): Promise<number> {
    const s = await PreferenceService.ensureStore();
    const value = await s.get(KEY_DEFAULT_TAB, 0);
    const idx: number = typeof value === 'number' ? value : 0;
    if (idx < 0 || idx >= TAB_COUNT) return 0;
    return idx;
  }

  static async setDefaultTab(idx: number): Promise<void> {
    if (idx < 0 || idx >= TAB_COUNT) return;
    const s = await PreferenceService.ensureStore();
    await s.put(KEY_DEFAULT_TAB, idx);
    await s.flush();
  }
}

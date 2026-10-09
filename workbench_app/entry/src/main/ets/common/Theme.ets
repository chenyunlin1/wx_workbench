import { AppColor } from '../theme/Theme'

/**
 * 业务页共用的语义色适配层：把旧版自定义色板统一收敛到模板设计系统。
 * - 品牌相关色走 AppColor.*（随「设置 → 主题色」实时变化）
 * - 中性色走 sys.color.* 系统资源（自动深浅色）
 * - 语义色（优先级/警告/成功）保留手工色值，通过 isDark() 深浅分档
 * 新增页面请直接使用 theme/Theme.ets 的 token。
 */
export class Theme {
  /** 由 EntryAbility 在启动与 onConfigurationUpdate 中同步到 AppStorage */
  static isDark(): boolean {
    const mode = AppStorage.get<string>('colorMode')
    return mode !== 'light'
  }

  /* -------- 页面背景 -------- */

  static get BG(): ResourceColor {
    return $r('sys.color.background_primary')
  }

  /* -------- 卡片 / 输入 -------- */

  static get CARD_TOP(): ResourceColor {
    return $r('sys.color.comp_background_primary')
  }

  static get CARD_BOTTOM(): ResourceColor {
    return $r('sys.color.comp_background_primary')
  }

  static get CARD_SOLID(): ResourceColor {
    return $r('sys.color.comp_background_primary')
  }

  static get INPUT_BG(): ResourceColor {
    return $r('sys.color.comp_background_tertiary')
  }

  /* -------- 品牌色（跟随主题色切换） -------- */

  static get PRIMARY(): ResourceColor {
    return AppColor.Brand
  }

  static get CYAN(): ResourceColor {
    return AppColor.Brand
  }

  static get MINT(): ResourceColor {
    return AppColor.Brand
  }

  static get VIOLET(): ResourceColor {
    return AppColor.BrandDark
  }

  /* -------- 语义色 -------- */

  static get DANGER(): ResourceColor {
    return AppColor.Danger
  }

  static get WARN(): ResourceColor {
    return Theme.isDark() ? '#FBBF24' : '#C77700'
  }

  static get SUCCESS(): ResourceColor {
    return Theme.isDark() ? '#34E1B5' : '#0A9E6E'
  }

  /* -------- 文字 -------- */

  static get TEXT(): ResourceColor {
    return $r('sys.color.font_primary')
  }

  static get TEXT_SUB(): ResourceColor {
    return $r('sys.color.font_secondary')
  }

  static get TEXT_FAINT(): ResourceColor {
    return $r('sys.color.font_tertiary')
  }

  /* -------- 边框 / 阴影 / 底栏 -------- */

  static get BORDER(): ResourceColor {
    return AppColor.Divider
  }

  static get BORDER_GLOW(): ResourceColor {
    return AppColor.Divider
  }

  static get SHADOW(): ResourceColor {
    return AppColor.Shadow
  }

  static get TAB_BAR(): ResourceColor {
    return $r('sys.color.background_primary')
  }

  /* -------- 半透明衍生色（仅用于 hex 输入） -------- */

  static softOf(hex: string, alpha: string): string {
    if (hex.length === 7 && hex.startsWith('#')) {
      return '#' + alpha + hex.substring(1)
    }
    return hex
  }

  static get PRIMARY_SOFT(): ResourceColor {
    return AppColor.BrandSoft
  }

  static get MINT_SOFT(): ResourceColor {
    return AppColor.BrandSoft
  }

  static get DANGER_SOFT(): string {
    return Theme.isDark() ? '#22F87171' : '#22E5484D'
  }

  /* -------- 渐变（卡片内使用；模板风为纯色填充） -------- */

  static get CARD_COLORS(): Array<[ResourceColor, number]> {
    return [
      [$r('sys.color.comp_background_primary'), 0.0],
      [$r('sys.color.comp_background_primary'), 1.0]
    ]
  }

  static get BRAND_COLORS(): Array<[ResourceColor, number]> {
    return [
      [AppColor.Brand, 0.0],
      [AppColor.Brand, 1.0]
    ]
  }

  static get MINT_COLORS(): Array<[ResourceColor, number]> {
    return [
      [AppColor.Brand, 0.0],
      [AppColor.Brand, 1.0]
    ]
  }

  static get VIOLET_COLORS(): Array<[ResourceColor, number]> {
    return [
      [AppColor.BrandDark, 0.0],
      [AppColor.Brand, 1.0]
    ]
  }

  /* -------- 优先级（两种模式通用） -------- */

  static readonly PRIORITY_COLORS: Record<string, string> = {
    'high': '#F87171',
    'medium': '#FBBF24',
    'low': '#34E1B5'
  }

  static readonly PRIORITY_LABELS: Record<string, string> = {
    'high': '高',
    'medium': '中',
    'low': '低'
  }

  static priorityColor(priority: string): string {
    const color = Theme.PRIORITY_COLORS[priority]
    return color === undefined ? '#FBBF24' : color
  }

  static priorityLabel(priority: string): string {
    const label = Theme.PRIORITY_LABELS[priority]
    return label === undefined ? priority : label
  }
}

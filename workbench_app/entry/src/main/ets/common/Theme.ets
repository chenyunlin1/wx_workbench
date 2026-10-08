/**
 * 主题：跟随系统深浅色模式。
 * 所有颜色是动态 getter —— 组件每次重建时按当前模式取值；
 * 模式切换时 EntryAbility 更新 AppStorage 的 colorMode，Index 触发整树重建。
 * 值保持 hex 字符串，半透明场景统一用 softOf()。
 */
export class Theme {
  static isDark(): boolean {
    const mode = AppStorage.get<string>('colorMode')
    return mode !== 'light'
  }

  /* -------- 页面背景（纯色，保证与状态栏/导航条区域无缝） -------- */

  static get BG(): string {
    return this.isDark() ? '#060B16' : '#F3F6FB'
  }

  /* -------- 卡片 -------- */

  static get CARD_TOP(): string {
    return this.isDark() ? '#111F3A' : '#FFFFFF'
  }

  static get CARD_BOTTOM(): string {
    return this.isDark() ? '#0C1730' : '#F7F9FE'
  }

  static get CARD_SOLID(): string {
    return this.isDark() ? '#0E1A32' : '#FFFFFF'
  }

  static get INPUT_BG(): string {
    return this.isDark() ? '#0B1730' : '#EEF2F9'
  }

  /* -------- 品牌色 -------- */

  static get PRIMARY(): string {
    return this.isDark() ? '#3B82F6' : '#2F6BFF'
  }

  static get CYAN(): string {
    return this.isDark() ? '#22D3EE' : '#0E9FCC'
  }

  static get MINT(): string {
    return this.isDark() ? '#34E1B5' : '#0FA98C'
  }

  static get VIOLET(): string {
    return this.isDark() ? '#8B7CF6' : '#7C5CF0'
  }

  /* -------- 语义色 -------- */

  static get DANGER(): string {
    return this.isDark() ? '#F87171' : '#E5484D'
  }

  static get WARN(): string {
    return this.isDark() ? '#FBBF24' : '#C77700'
  }

  static get SUCCESS(): string {
    return this.isDark() ? '#34D399' : '#0A9E6E'
  }

  /* -------- 文字 -------- */

  static get TEXT(): string {
    return this.isDark() ? '#E8F0FE' : '#17233B'
  }

  static get TEXT_SUB(): string {
    return this.isDark() ? '#93A7C8' : '#54637F'
  }

  static get TEXT_FAINT(): string {
    return this.isDark() ? '#5E7599' : '#93A0B8'
  }

  /* -------- 边框 / 阴影 / 底栏 -------- */

  static get BORDER(): string {
    return this.isDark() ? '#1B2C4F' : '#E2E8F3'
  }

  static get BORDER_GLOW(): string {
    return this.isDark() ? '#2A4A85' : '#C2CFE6'
  }

  static get SHADOW(): string {
    return this.isDark() ? '#40000000' : '#26334D80'
  }

  static get TAB_BAR(): string {
    return this.isDark() ? '#0A1426' : '#FFFFFF'
  }

  /* -------- 半透明衍生色（AARRGGBB） -------- */

  static softOf(hex: string, alpha: string): string {
    if (hex.length === 7 && hex.startsWith('#')) {
      return '#' + alpha + hex.substring(1)
    }
    return hex
  }

  static get PRIMARY_SOFT(): string {
    return this.softOf(this.PRIMARY, '44')
  }

  static get MINT_SOFT(): string {
    return this.softOf(this.MINT, '22')
  }

  static get DANGER_SOFT(): string {
    return this.softOf(this.DANGER, '22')
  }

  /* -------- 渐变（仅卡片内部使用，页面背景用纯色避免色差） -------- */

  static get CARD_COLORS(): Array<[ResourceColor, number]> {
    return [
      [this.CARD_TOP, 0.0],
      [this.CARD_BOTTOM, 1.0]
    ]
  }

  static get BRAND_COLORS(): Array<[ResourceColor, number]> {
    return [
      [this.PRIMARY, 0.0],
      [this.CYAN, 1.0]
    ]
  }

  static get MINT_COLORS(): Array<[ResourceColor, number]> {
    return [
      [this.MINT, 0.0],
      [this.CYAN, 1.0]
    ]
  }

  static get VIOLET_COLORS(): Array<[ResourceColor, number]> {
    return [
      [this.VIOLET, 0.0],
      [this.PRIMARY, 1.0]
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

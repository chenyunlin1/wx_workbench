/**
 * 手机、折叠屏、平板和电脑共用容器断点，不用设备型号代替可用窗口尺寸。
 */
export class AdaptiveLayout {
  static readonly MEDIUM_WIDTH: number = 600;
  static readonly LARGE_WIDTH: number = 840;

  private static readonly COMPACT_WIDTH: number = 360;
  private static readonly COMPACT_HEIGHT: number = 760;

  static isCompact(width: number, height: number): boolean {
    if (width <= 0 || height <= 0) return false;
    return width < AdaptiveLayout.COMPACT_WIDTH || height < AdaptiveLayout.COMPACT_HEIGHT;
  }

  static horizontalPadding(width: number, height: number): number {
    return AdaptiveLayout.isCompact(width, height) ? 16 : 24;
  }

  static sectionSpacing(width: number, height: number): number {
    return AdaptiveLayout.isCompact(width, height) ? 16 : 24;
  }
}

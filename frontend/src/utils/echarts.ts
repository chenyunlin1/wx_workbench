/**
 * ECharts 按需引入：只注册用到的图表与组件，避免把整包打进产物。
 * 颜色统一从主题 CSS 变量读取，深浅色主题自动跟随。
 */
import { BarChart, LineChart } from 'echarts/charts'
import { GridComponent, LegendComponent, TooltipComponent } from 'echarts/components'
import * as echarts from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([
  BarChart,
  LineChart,
  GridComponent,
  TooltipComponent,
  LegendComponent,
  CanvasRenderer,
])

export { echarts }

export type ChartOption = Record<string, unknown>

export interface ChartTokens {
  primary: string
  secondary: string
  accent: string
  warning: string
  danger: string
  cyan: string
  rose: string
  text: string
  muted: string
  border: string
  surface: string
  fontFamily: string
}

const readVar = (name: string, fallback: string) => {
  if (typeof window === 'undefined') return fallback
  const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  return value || fallback
}

/** 图表统一色板：全部为纯色，避免彩色渐变 */
export const chartTokens = (): ChartTokens => ({
  primary: readVar('--primary', '#3b82f6'),
  secondary: readVar('--secondary', '#10b981'),
  accent: readVar('--accent', '#8b5cf6'),
  warning: readVar('--warning', '#f59e0b'),
  danger: readVar('--danger', '#ef4444'),
  cyan: '#06b6d4',
  rose: '#f43f5e',
  text: readVar('--text-primary', '#172033'),
  muted: readVar('--text-secondary', '#8290a6'),
  border: readVar('--border-soft', 'rgba(148, 163, 184, 0.35)'),
  surface: readVar('--surface', '#ffffff'),
  fontFamily: readVar('--font-sans', 'Inter, "PingFang SC", "Microsoft YaHei", system-ui, sans-serif'),
})

/** 把主题色转成带透明度的纯色（用于面积填充，替代渐变色） */
export const withAlpha = (color: string, alpha: number) => {
  const hex = color.trim().replace('#', '')
  if (/^[0-9a-f]{6}$/i.test(hex)) {
    const r = parseInt(hex.slice(0, 2), 16)
    const g = parseInt(hex.slice(2, 4), 16)
    const b = parseInt(hex.slice(4, 6), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
  const rgb = color.match(/rgba?\(([^)]+)\)/)
  if (rgb) {
    const [r, g, b] = rgb[1].split(',').map((part) => Number(part.trim()))
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
  return color
}

/** 分类色板：全部为纯色（不使用彩色渐变） */
export const chartPalette = (tokens: ChartTokens) => [
  tokens.primary,
  tokens.cyan,
  tokens.secondary,
  tokens.accent,
  tokens.warning,
  tokens.rose,
]

/** 轴名与绘图区上沿的距离；ECharts 默认的 15 会把单位顶到图例那一行里 */
export const AXIS_NAME_GAP = 8

/**
 * 带图例图表的统一外框：图例独占顶部一行，坐标轴单位名贴着绘图区上沿，
 * 两者分行就不会叠在一起（grid.top 必须容得下这两行）。
 */
export const legendFrame = (tokens: ChartTokens) => ({
  grid: { left: 46, right: 52, top: 48, bottom: 26 },
  legend: {
    top: 0,
    right: 0,
    itemWidth: 10,
    itemHeight: 10,
    itemGap: 14,
    textStyle: { color: tokens.muted, fontSize: 11 },
  },
})

/** 配合 legendFrame 使用的轴名样式 */
export const axisName = (tokens: ChartTokens) => ({
  nameTextStyle: { color: tokens.muted, fontSize: 11 },
  nameGap: AXIS_NAME_GAP,
})

/** 各类图表共用的基础样式 */
export const baseChartStyle = (tokens: ChartTokens) => ({
  textStyle: { fontFamily: tokens.fontFamily, color: tokens.muted },
  tooltip: {
    backgroundColor: tokens.surface,
    borderColor: tokens.border,
    borderWidth: 1,
    padding: [8, 12],
    textStyle: { color: tokens.text, fontSize: 12 },
    extraCssText: 'border-radius: 10px; box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);',
  },
  axisLabel: { color: tokens.muted, fontSize: 11 },
  splitLine: { lineStyle: { color: tokens.border, type: 'dashed' as const } },
})

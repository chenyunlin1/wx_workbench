<script setup lang="ts">
import { computed } from 'vue'
import BaseChart from './BaseChart.vue'
import { useThemeStore } from '@/stores/theme'
import { baseChartStyle, chartTokens, withAlpha } from '@/utils/echarts'
import type { Health } from '@/types'

const props = withDefaults(
  defineProps<{
    records: Health[]
    height?: number
  }>(),
  { height: 180 },
)

const themeStore = useThemeStore()

const option = computed(() => {
  // 读取主题，切换深浅色时重新取色
  void themeStore.theme
  const tokens = chartTokens()
  const base = baseChartStyle(tokens)
  const dates = props.records.map((record) => record.recordDate)
  const weights = props.records.map((record) => Number(record.weight))

  return {
    textStyle: base.textStyle,
    grid: { left: 46, right: 16, top: 18, bottom: 26 },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      valueFormatter: (value: number) => `${value} kg`,
    },
    xAxis: {
      type: 'category',
      data: dates,
      boundaryGap: false,
      axisLine: { lineStyle: { color: tokens.border } },
      axisTick: { show: false },
      axisLabel: { ...base.axisLabel, formatter: (value: string) => value.slice(5) },
    },
    yAxis: {
      type: 'value',
      scale: true,
      splitNumber: 4,
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: base.splitLine,
      axisLabel: base.axisLabel,
    },
    series: [
      {
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 7,
        showSymbol: weights.length <= 16,
        data: weights,
        lineStyle: { width: 2, color: tokens.primary },
        itemStyle: { color: tokens.primary, borderColor: tokens.surface, borderWidth: 2 },
        areaStyle: { color: withAlpha(tokens.primary, 0.12) },
      },
    ],
  }
})
</script>

<template>
  <BaseChart
    v-if="records.length"
    :option="option"
    :height="height"
    :aria-label="`最近 ${records.length} 次体重趋势`"
  />
  <div v-else class="chart-empty" :style="{ height: `${height}px` }">暂无体重记录</div>
</template>

<style scoped>
.chart-empty {
  display: grid;
  place-items: center;
  color: var(--text-secondary);
  font-size: 12px;
}
</style>

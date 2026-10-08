<script setup lang="ts">
import { computed } from 'vue'
import { ArrowRight, DataLine, ScaleToOriginal } from '@element-plus/icons-vue'
import dayjs from 'dayjs'
import BaseChart from '@/components/charts/BaseChart.vue'
import { useThemeStore } from '@/stores/theme'
import { baseChartStyle, chartTokens, withAlpha } from '@/utils/echarts'
import type { Health } from '@/types'

const props = defineProps<{
  latestWeight: number | null
  sevenDayAverage: number | null
  records: Health[]
  loading?: boolean
}>()

const themeStore = useThemeStore()

const chartRecords = computed(() => props.records.slice(-7))

const formatWeight = (value: number | null) => (value === null ? '--' : Number(value).toFixed(1))

/** 迷你体重走势：无坐标轴，仅保留曲线、数据点与提示 */
const sparkOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const base = baseChartStyle(tokens)
  const weights = chartRecords.value.map((item) => Number(item.weight))

  return {
    textStyle: base.textStyle,
    grid: { left: 10, right: 12, top: 12, bottom: 22 },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      valueFormatter: (value: number) => `${value} kg`,
    },
    xAxis: {
      type: 'category',
      data: chartRecords.value.map((item) => item.recordDate),
      boundaryGap: false,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: {
        ...base.axisLabel,
        formatter: (value: string) => dayjs(value).format('dd'),
      },
    },
    yAxis: {
      type: 'value',
      scale: true,
      splitNumber: 2,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { show: false },
      splitLine: base.splitLine,
    },
    series: [
      {
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 7,
        data: weights,
        lineStyle: { width: 2, color: tokens.secondary },
        itemStyle: { color: tokens.secondary, borderColor: tokens.surface, borderWidth: 2 },
        areaStyle: { color: withAlpha(tokens.secondary, 0.14) },
      },
    ],
  }
})
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card health-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon green"><el-icon><ScaleToOriginal /></el-icon></span>
          <div>
            <h3>健康摘要</h3>
            <p>关注身体的微小变化</p>
          </div>
        </div>
        <router-link class="text-link" to="/fitness">减脂健身 <el-icon><ArrowRight /></el-icon></router-link>
      </div>
    </template>

    <div class="weight-panel">
      <div>
        <span>最新体重</span>
        <strong>{{ formatWeight(latestWeight) }}<small>kg</small></strong>
      </div>
      <div class="average">
        <el-icon><DataLine /></el-icon>
        <span>7日均值</span>
        <strong>{{ formatWeight(sevenDayAverage) }} kg</strong>
      </div>
    </div>

    <div class="mini-chart">
      <BaseChart
        v-if="chartRecords.length > 1"
        :option="sparkOption"
        :height="104"
        aria-label="近七日体重趋势"
      />
      <div v-else class="chart-empty">还没有健康记录</div>
    </div>

    <div class="health-tip">
      <i />
      <span>{{ records.length ? '近 7 天记录稳定，继续保持' : '添加第一条体重记录，开始追踪趋势' }}</span>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.health-card {
  min-height: 286px;
}

.card-heading,
.heading-copy,
.text-link {
  display: flex;
  align-items: center;
}

.card-heading {
  justify-content: space-between;
  gap: 12px;
}

.heading-copy {
  gap: 10px;
}

.heading-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 11px;
  font-size: 18px;
}

.heading-icon.green {
  color: var(--secondary);
  background: var(--secondary-soft);
}

h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 16px;
}

.heading-copy p {
  margin: 3px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.text-link {
  gap: 2px;
  color: var(--text-secondary);
  font-size: 13px;
}

.text-link:hover {
  color: var(--primary);
}

.weight-panel {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding-bottom: 5px;
}

.weight-panel > div:first-child > span {
  display: block;
  color: var(--text-secondary);
  font-size: 12px;
}

.weight-panel > div:first-child > strong {
  color: var(--text-primary);
  font-size: 30px;
  letter-spacing: -0.04em;
}

.weight-panel > div:first-child small {
  margin-left: 4px;
  color: var(--text-secondary);
  font-size: 12px;
}

.average {
  display: grid;
  grid-template-columns: auto auto;
  gap: 2px 5px;
  align-items: center;
  padding: 7px 9px;
  border-radius: 10px;
  color: var(--secondary);
  background: var(--secondary-soft);
}

.average .el-icon {
  grid-row: span 2;
}

.average span {
  font-size: 12px;
}

.average strong {
  font-size: 12px;
}

.mini-chart {
  margin-top: 4px;
}

.chart-empty {
  display: grid;
  height: 104px;
  place-items: center;
  color: var(--text-secondary);
  font-size: 12px;
}

.health-tip {
  display: flex;
  align-items: center;
  gap: 6px;
  padding-top: 9px;
  color: var(--text-secondary);
  font-size: 12px;
}

.health-tip i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--secondary);
  box-shadow: 0 0 0 3px var(--secondary-soft);
}
</style>
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import dayjs from 'dayjs'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Delete,
  Edit,
  Lightning,
  Medal,
  Plus,
  Stopwatch,
  TrendCharts,
} from '@element-plus/icons-vue'
import {
  createWorkout,
  deleteWorkout,
  getWorkoutStats,
  listWorkouts,
  updateWorkout,
} from '@/api/workout'
import { getHealthTrend } from '@/api/health'
import WorkoutFormDialog from './components/WorkoutFormDialog.vue'
import BaseChart from '@/components/charts/BaseChart.vue'
import WeightChart from '@/components/charts/WeightChart.vue'
import { useThemeStore } from '@/stores/theme'
import {
  axisName,
  baseChartStyle,
  chartPalette,
  chartTokens,
  legendFrame,
  withAlpha,
} from '@/utils/echarts'
import { WINDOW_OPTIONS, WORKOUT_TYPES, intensityLabel, workoutMeta } from './workout-meta'
import type { HealthTrend, Workout, WorkoutPayload, WorkoutStats, WorkoutType } from '@/types'

const PAGE_SIZE = 10

const themeStore = useThemeStore()

const stats = ref<WorkoutStats | null>(null)
const records = ref<Workout[]>([])
const total = ref(0)
const page = ref(1)
const windowDays = ref<number>(7)
const typeFilter = ref<WorkoutType | ''>('')
const loading = ref(false)
const saving = ref(false)
const dialogVisible = ref(false)
const editing = ref<Workout | null>(null)
const healthTrend = ref<HealthTrend | null>(null)

const weightRecords = computed(() => healthTrend.value?.records ?? [])
const latestWeight = computed(() => healthTrend.value?.latest ?? null)
const weightDelta = computed(() => {
  const list = weightRecords.value
  if (list.length < 2) return null
  return Number((Number(list[list.length - 1].weight) - Number(list[0].weight)).toFixed(1))
})

const typeChartHeight = computed(() =>
  Math.max(130, (stats.value?.byType.length ?? 0) * 40 + 40),
)

/** 每日训练时长（柱）+ 消耗（折线，右轴） */
const dailyOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const base = baseChartStyle(tokens)
  const daily = stats.value?.daily ?? []

  return {
    textStyle: base.textStyle,
    ...legendFrame(tokens),
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow', shadowStyle: { color: withAlpha(tokens.primary, 0.06) } },
      formatter: (params: Array<{ axisValue: string; seriesName: string; value: number }>) => {
        const head = params[0]?.axisValue ?? ''
        const rows = params.map(
          (item) =>
            `<div style="display:flex;gap:10px;justify-content:space-between"><span>${item.seriesName}</span><b>${item.value}${item.seriesName === '消耗' ? ' 千卡' : ' 分钟'}</b></div>`,
        )
        return `<div style="margin-bottom:4px">${head}</div>${rows.join('')}`
      },
    },
    xAxis: {
      type: 'category',
      data: daily.map((item) => item.date.slice(5)),
      axisLine: { lineStyle: { color: tokens.border } },
      axisTick: { show: false },
      axisLabel: base.axisLabel,
    },
    yAxis: [
      {
        type: 'value',
        name: '分钟',
        ...axisName(tokens),
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: base.splitLine,
        axisLabel: base.axisLabel,
      },
      {
        type: 'value',
        name: '千卡',
        ...axisName(tokens),
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: { show: false },
        axisLabel: base.axisLabel,
      },
    ],
    series: [
      {
        name: '训练时长',
        type: 'bar',
        barWidth: 16,
        data: daily.map((item) => item.duration),
        itemStyle: { color: tokens.primary, borderRadius: [5, 5, 0, 0] },
      },
      {
        name: '消耗',
        type: 'line',
        yAxisIndex: 1,
        smooth: true,
        symbol: 'circle',
        symbolSize: 7,
        data: daily.map((item) => item.calories),
        lineStyle: { width: 2, color: tokens.warning },
        itemStyle: { color: tokens.warning, borderColor: tokens.surface, borderWidth: 2 },
      },
    ],
  }
})

/** 按类型的训练时长（横向条形） */
const typeOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const base = baseChartStyle(tokens)
  const palette = chartPalette(tokens)
  const byType = stats.value?.byType ?? []

  return {
    textStyle: base.textStyle,
    grid: { left: 84, right: 72, top: 6, bottom: 6 },
    tooltip: {
      ...base.tooltip,
      trigger: 'item',
      formatter: (params: { dataIndex: number }) => {
        const item = byType[params.dataIndex]
        if (!item) return ''
        return [
          `<div style="margin-bottom:4px">${workoutMeta(item.type).emoji} ${workoutMeta(item.type).label}</div>`,
          `<div>时长 <b>${item.duration}</b> 分钟</div>`,
          `<div>次数 <b>${item.sessions}</b> 次</div>`,
          `<div>消耗 <b>${item.calories}</b> 千卡</div>`,
        ].join('')
      },
    },
    xAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: base.splitLine,
      axisLabel: base.axisLabel,
    },
    yAxis: {
      type: 'category',
      inverse: true,
      data: byType.map((item) => workoutMeta(item.type).label),
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { ...base.axisLabel, fontSize: 12 },
    },
    series: [
      {
        type: 'bar',
        barWidth: 14,
        data: byType.map((item, index) => ({
          value: item.duration,
          itemStyle: { color: palette[index % palette.length], borderRadius: [0, 6, 6, 0] },
        })),
        label: {
          show: true,
          position: 'right',
          formatter: '{c} 分钟',
          color: tokens.muted,
          fontSize: 11,
        },
      },
    ],
  }
})

const loadStats = async () => {
  stats.value = await getWorkoutStats(windowDays.value)
}

const loadRecords = async () => {
  loading.value = true
  try {
    const result = await listWorkouts({
      type: typeFilter.value || undefined,
      page: page.value,
      pageSize: PAGE_SIZE,
    })
    records.value = result.items
    total.value = result.total
  } finally {
    loading.value = false
  }
}

const loadWeight = async () => {
  healthTrend.value = await getHealthTrend(30)
}

const refresh = async () => {
  await Promise.all([loadStats(), loadRecords()])
}

const openCreate = () => {
  editing.value = null
  dialogVisible.value = true
}

const openEdit = (workout: Workout) => {
  editing.value = workout
  dialogVisible.value = true
}

const handleSave = async (payload: WorkoutPayload) => {
  saving.value = true
  try {
    if (editing.value) await updateWorkout(editing.value.id, payload)
    else await createWorkout(payload)
    ElMessage.success(editing.value ? '训练记录已更新' : '训练已记录')
    dialogVisible.value = false
    await refresh()
  } finally {
    saving.value = false
  }
}

const handleDelete = async (workout: Workout) => {
  await ElMessageBox.confirm(
    `确定删除 ${dayjs(workout.workoutDate).format('MM-DD HH:mm')} 的「${
      workout.title ?? workoutMeta(workout.type).label
    }」吗？`,
    '删除训练记录',
    { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' },
  )
  await deleteWorkout(workout.id)
  ElMessage.success('训练记录已删除')
  if (records.value.length === 1 && page.value > 1) page.value -= 1
  await refresh()
}

watch(windowDays, () => void loadStats())
watch(typeFilter, () => {
  page.value = 1
  void loadRecords()
})
watch(page, () => void loadRecords())

onMounted(async () => {
  await Promise.all([refresh(), loadWeight()])
})
</script>

<template>
  <section class="fitness-page">
    <header class="page-heading">
      <div>
        <p>TRAINING LOG</p>
        <h2>减脂健身</h2>
        <span>记录训练量与体重变化，看清努力的轨迹。</span>
      </div>
      <div class="heading-actions">
        <el-radio-group v-model="windowDays" class="window-switch">
          <el-radio-button v-for="item in WINDOW_OPTIONS" :key="item.value" :value="item.value">
            {{ item.label }}
          </el-radio-button>
        </el-radio-group>
        <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon>记录训练</el-button>
      </div>
    </header>

    <div class="summary-grid">
      <div class="summary-card">
        <span class="summary-icon primary"><el-icon><Medal /></el-icon></span>
        <div>
          <small>训练次数</small>
          <strong>{{ stats?.sessions ?? 0 }}<em>次</em></strong>
          <span class="summary-note">本月 {{ stats?.month.sessions ?? 0 }} 次 · 累计 {{ stats?.lifetime.sessions ?? 0 }} 次</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon secondary"><el-icon><Stopwatch /></el-icon></span>
        <div>
          <small>总时长</small>
          <strong>{{ stats?.duration ?? 0 }}<em>分钟</em></strong>
          <span class="summary-note">平均 {{ stats?.averageDuration ?? 0 }} 分钟/次</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon warning"><el-icon><Lightning /></el-icon></span>
        <div>
          <small>总消耗</small>
          <strong>{{ stats?.calories ?? 0 }}<em>千卡</em></strong>
          <span class="summary-note">累计 {{ stats?.lifetime.calories ?? 0 }} 千卡</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon accent"><el-icon><TrendCharts /></el-icon></span>
        <div>
          <small>连续训练</small>
          <strong>{{ stats?.streakDays ?? 0 }}<em>天</em></strong>
          <span class="summary-note">
            {{ latestWeight ? `当前体重 ${Number(latestWeight.weight).toFixed(1)} kg` : '暂无体重记录' }}
          </span>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <section v-loading="loading" class="panel">
        <header class="panel-head">
          <div>
            <h3>训练分布</h3>
            <p>{{ stats?.range.from }} ~ {{ stats?.range.to }} 每日训练时长（分钟）</p>
          </div>
        </header>

        <BaseChart
          v-if="stats?.daily.length"
          :option="dailyOption"
          :height="210"
          :aria-label="`近 ${windowDays} 天每日训练时长与消耗`"
        />
        <div v-else class="chart-empty">暂无训练数据</div>

        <div v-if="stats?.byType.length" class="type-chart">
          <p class="sub-title">按训练类型</p>
          <BaseChart :option="typeOption" :height="typeChartHeight" aria-label="按训练类型的时长分布" />
        </div>
      </section>

      <section class="panel">
        <header class="panel-head">
          <div>
            <h3>体重趋势</h3>
            <p>最近 30 次体重记录</p>
          </div>
          <el-tag v-if="weightDelta !== null" size="small" :type="weightDelta <= 0 ? 'success' : 'danger'" effect="light">
            {{ weightDelta > 0 ? '+' : '' }}{{ weightDelta }} kg
          </el-tag>
        </header>

        <WeightChart :records="weightRecords" :height="180" />

        <div class="weight-stats">
          <div>
            <small>最新</small>
            <strong>{{ latestWeight ? Number(latestWeight.weight).toFixed(1) : '—' }}</strong>
            <span class="unit">kg</span>
          </div>
          <div>
            <small>平均</small>
            <strong>{{ healthTrend?.average ?? '—' }}</strong>
            <span class="unit">kg</span>
          </div>
          <div>
            <small>记录</small>
            <strong>{{ weightRecords.length }}</strong>
            <span class="unit">条</span>
          </div>
        </div>

        <p class="panel-tip">到「习惯健康」页可以补充或修改体重记录。</p>
      </section>
    </div>

    <section v-loading="loading" class="panel">
      <header class="panel-head">
        <div>
          <h3>训练记录</h3>
          <p>共 {{ total }} 条</p>
        </div>
        <el-select v-model="typeFilter" size="small" clearable placeholder="全部类型" class="type-filter">
          <el-option label="全部类型" value="" />
          <el-option v-for="item in WORKOUT_TYPES" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </header>

      <div v-if="!loading && !records.length" class="empty-block">
        <span class="empty-icon"><el-icon><Stopwatch /></el-icon></span>
        <strong>还没有训练记录</strong>
        <p>记录第一次训练，统计就会开始累积</p>
        <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon>记录训练</el-button>
      </div>

      <div v-else class="record-list">
        <article v-for="workout in records" :key="workout.id" class="record-row">
          <span class="record-emoji" :class="workoutMeta(workout.type).tone">
            {{ workoutMeta(workout.type).emoji }}
          </span>

          <div class="record-main">
            <strong>{{ workout.title || workoutMeta(workout.type).label }}</strong>
            <span>{{ workout.note || workoutMeta(workout.type).label }}</span>
          </div>

          <div class="record-meta">
            <span class="chip">{{ workout.duration }} 分钟</span>
            <span v-if="workout.calories" class="chip">{{ workout.calories }} 千卡</span>
            <span v-if="workout.distance" class="chip">{{ Number(workout.distance) }} 公里</span>
            <span class="chip" :class="`is-${workout.intensity}`">{{ intensityLabel(workout.intensity) }}</span>
          </div>

          <span class="record-date">{{ dayjs(workout.workoutDate).format('MM-DD HH:mm') }}</span>

          <div class="record-actions">
            <el-button text size="small" @click="openEdit(workout)"><el-icon><Edit /></el-icon>编辑</el-button>
            <el-button text size="small" type="danger" @click="handleDelete(workout)">
              <el-icon><Delete /></el-icon>删除
            </el-button>
          </div>
        </article>
      </div>

      <div v-if="total > PAGE_SIZE" class="pagination-wrap">
        <el-pagination
          v-model:current-page="page"
          :page-size="PAGE_SIZE"
          :total="total"
          layout="prev, pager, next"
          background
        />
      </div>
    </section>

    <WorkoutFormDialog v-model="dialogVisible" :workout="editing" :saving="saving" @save="handleSave" />
  </section>
</template>

<style scoped lang="scss">
.fitness-page {
  display: grid;
  gap: 18px;
  animation: fitness-in 0.35s ease both;
}

@keyframes fitness-in {
  from {
    opacity: 0;
    transform: translateY(7px);
  }
}

.page-heading {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
  align-items: flex-end;
  justify-content: space-between;
}

.page-heading p {
  margin: 0 0 6px;
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.18em;
}

.page-heading h2 {
  margin: 0;
  color: var(--text-primary);
  font-size: 28px;
  letter-spacing: -0.04em;
}

.page-heading span {
  display: block;
  margin-top: 7px;
  color: var(--text-secondary);
  font-size: 13px;
}

.heading-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}

.summary-card {
  display: flex;
  min-height: 104px;
  align-items: center;
  gap: 14px;
  padding: 18px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.summary-icon {
  display: grid;
  width: 44px;
  height: 44px;
  flex: none;
  place-items: center;
  border-radius: 13px;
  font-size: 20px;
}

.summary-icon.primary {
  color: var(--primary);
  background: var(--primary-soft);
}

.summary-icon.secondary {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.summary-icon.warning {
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, transparent);
}

.summary-icon.accent {
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 14%, transparent);
}

.summary-card small {
  display: block;
  margin-bottom: 6px;
  color: var(--text-secondary);
  font-size: 12px;
}

.summary-card strong {
  color: var(--text-primary);
  font-size: 24px;
  letter-spacing: -0.035em;
}

.summary-card strong em {
  margin-left: 2px;
  color: var(--text-secondary);
  font-size: 13px;
  font-style: normal;
}

.summary-note {
  display: block;
  margin-top: 5px;
  color: var(--text-secondary);
  font-size: 12px;
}

.grid-2 {
  display: grid;
  grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

.panel {
  padding: 16px 18px 18px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}

.panel-head h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 16px;
}

.panel-head p {
  margin: 4px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.chart-empty {
  display: grid;
  height: 210px;
  place-items: center;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
  background: var(--surface-muted);
  font-size: 12px;
}

.type-chart {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px dashed var(--border-soft);
}

.sub-title {
  margin: 0 0 6px;
  color: var(--text-secondary);
  font-size: 12px;
}

.weight-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  margin-top: 12px;
}

.weight-stats > div {
  padding: 10px 12px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.weight-stats small {
  display: block;
  color: var(--text-secondary);
  font-size: 12px;
}

.weight-stats strong {
  color: var(--text-primary);
  font-size: 19px;
}

.unit {
  margin-left: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.panel-tip {
  margin: 12px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.type-filter {
  width: 130px;
}

.record-list {
  display: grid;
  gap: 9px;
}

.record-row {
  display: grid;
  grid-template-columns: 42px minmax(140px, 1fr) auto 96px auto;
  align-items: center;
  gap: 12px;
  padding: 11px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
  transition: all 0.18s ease;
}

.record-row:hover {
  border-color: color-mix(in srgb, var(--primary) 25%, var(--border-color));
  background: color-mix(in srgb, var(--primary-soft) 30%, var(--surface));
}

.record-emoji {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border-radius: 12px;
  font-size: 19px;
}

.record-emoji.blue {
  background: var(--primary-soft);
}

.record-emoji.violet {
  background: color-mix(in srgb, var(--accent) 15%, transparent);
}

.record-emoji.green {
  background: var(--secondary-soft);
}

.record-emoji.teal {
  background: color-mix(in srgb, #22d3ee 15%, transparent);
}

.record-emoji.rose {
  background: color-mix(in srgb, #fb7185 15%, transparent);
}

.record-emoji.orange {
  background: color-mix(in srgb, var(--warning) 15%, transparent);
}

.record-main {
  min-width: 0;
}

.record-main strong,
.record-main span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.record-main strong {
  color: var(--text-primary);
  font-size: 14px;
}

.record-main span {
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 12px;
}

.record-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}

.chip {
  padding: 2px 8px;
  border-radius: 99px;
  color: var(--text-regular);
  background: var(--surface);
  font-size: 12px;
}

.chip.is-low {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.chip.is-high {
  color: var(--danger);
  background: color-mix(in srgb, var(--danger) 12%, transparent);
}

.record-date {
  color: var(--text-secondary);
  font-size: 13px;
}

.record-actions {
  display: flex;
  justify-content: flex-end;
}

.empty-block {
  display: grid;
  place-items: center;
  align-content: center;
  gap: 9px;
  padding: 34px 20px;
  border: 1px dashed var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
  text-align: center;
}

.empty-icon {
  display: grid;
  width: 56px;
  height: 56px;
  place-items: center;
  border-radius: 18px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 25px;
}

.empty-block strong {
  color: var(--text-primary);
  font-size: 14px;
}

.empty-block p {
  margin: 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.pagination-wrap {
  display: flex;
  justify-content: flex-end;
  padding-top: 15px;
}

@media (max-width: 1080px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .grid-2 {
    grid-template-columns: 1fr;
  }

  .record-row {
    grid-template-columns: 42px minmax(110px, 1fr) 96px auto;
  }

  .record-meta {
    display: none;
  }
}

@media (max-width: 720px) {
  .summary-grid {
    grid-template-columns: 1fr;
  }

  .record-row {
    grid-template-columns: 42px minmax(90px, 1fr) auto;
  }

  .record-actions {
    grid-column: span 2;
    justify-content: flex-end;
  }
}
</style>

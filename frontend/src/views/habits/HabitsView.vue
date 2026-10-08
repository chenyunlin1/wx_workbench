<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import dayjs from 'dayjs'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Check,
  Delete,
  Edit,
  Plus,
  Sunny,
  TrendCharts,
} from '@element-plus/icons-vue'
import {
  cancelHabitCheckIn,
  checkInHabit,
  createHabit,
  deleteHabit,
  getHabitStats,
  updateHabit,
} from '@/api/habits'
import { createHealth, deleteHealth, listHealth, updateHealth } from '@/api/health'
import HabitFormDialog from './components/HabitFormDialog.vue'
import HealthFormDialog from './components/HealthFormDialog.vue'
import BaseChart from '@/components/charts/BaseChart.vue'
import WeightChart from '@/components/charts/WeightChart.vue'
import { useThemeStore } from '@/stores/theme'
import { baseChartStyle, chartTokens } from '@/utils/echarts'
import type {
  HabitPayload,
  HabitStatItem,
  HabitStats,
  Health,
  HealthPayload,
} from '@/types'

const stats = ref<HabitStats | null>(null)
const healthRecords = ref<Health[]>([])
const loading = ref(false)
const saving = ref(false)
const themeStore = useThemeStore()

const habitDialog = ref(false)
const editingHabit = ref<HabitStatItem | null>(null)
const healthDialog = ref(false)
const editingHealth = ref<Health | null>(null)

const habitCards = computed(() => stats.value?.habits ?? [])
const heat = computed(() => stats.value?.daily ?? [])

/** 图表用最近 30 条，接口按时间倒序返回 */
const chartRecords = computed(() => [...healthRecords.value].slice(0, 30).reverse())
const latest = computed(() => healthRecords.value[0] ?? null)
const previous = computed(() => healthRecords.value[1] ?? null)

const deltaTo = (current: Health | null, base: Health | null) => {
  if (!current || !base) return null
  return Number((Number(current.weight) - Number(base.weight)).toFixed(1))
}

const lastDelta = computed(() => deltaTo(latest.value, previous.value))
const windowDelta = computed(() =>
  chartRecords.value.length > 1
    ? deltaTo(chartRecords.value[chartRecords.value.length - 1], chartRecords.value[0])
    : null,
)
const windowRange = computed(() => {
  const values = chartRecords.value.map((record) => Number(record.weight))
  if (!values.length) return null
  return { min: Math.min(...values), max: Math.max(...values) }
})
const healthList = computed(() => healthRecords.value.slice(0, 8))

const deltaText = (delta: number | null) => {
  if (delta === null) return '—'
  if (delta === 0) return '持平'
  return `${delta > 0 ? '+' : ''}${delta.toFixed(1)} kg`
}

const deltaClass = (delta: number | null) => {
  if (delta === null || delta === 0) return 'flat'
  return delta < 0 ? 'down' : 'up'
}

/** 列表里每条相对上一条（更早）的变化 */
const deltaOf = (record: Health, index: number) => {
  const older = healthRecords.value[index + 1]
  return deltaTo(record, older ?? null)
}

const load = async () => {
  loading.value = true
  try {
    const [habitStats, records] = await Promise.all([getHabitStats(14), listHealth()])
    stats.value = habitStats
    healthRecords.value = records
  } finally {
    loading.value = false
  }
}

const toggleCheck = async (habit: HabitStatItem) => {
  try {
    const result = habit.checkedToday
      ? await cancelHabitCheckIn(habit.id)
      : await checkInHabit(habit.id)

    ElMessage.success(
      result.checkedToday
        ? `「${habit.name}」打卡成功，连续 ${result.streakDays} 天`
        : `已取消「${habit.name}」今日打卡`,
    )
    await load()
  } catch {
    // 拦截器已提示
  }
}

const openHabit = (habit: HabitStatItem | null = null) => {
  editingHabit.value = habit
  habitDialog.value = true
}

const saveHabit = async (payload: HabitPayload) => {
  saving.value = true
  try {
    if (editingHabit.value) await updateHabit(editingHabit.value.id, payload)
    else await createHabit(payload)
    ElMessage.success(editingHabit.value ? '习惯已更新' : '习惯已创建')
    habitDialog.value = false
    await load()
  } finally {
    saving.value = false
  }
}

const removeHabit = async (habit: HabitStatItem) => {
  await ElMessageBox.confirm(
    `删除「${habit.name}」会同时删除它的全部打卡记录，确定继续吗？`,
    '删除习惯',
    { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' },
  )
  await deleteHabit(habit.id)
  ElMessage.success('习惯已删除')
  await load()
}

const openHealth = (record: Health | null = null) => {
  editingHealth.value = record
  healthDialog.value = true
}

const saveHealth = async (payload: HealthPayload) => {
  saving.value = true
  try {
    if (editingHealth.value) await updateHealth(editingHealth.value.id, payload)
    else await createHealth(payload)
    ElMessage.success(editingHealth.value ? '体重记录已更新' : '体重已记录')
    healthDialog.value = false
    await load()
  } finally {
    saving.value = false
  }
}

const removeHealth = async (record: Health) => {
  await ElMessageBox.confirm(`确定删除 ${record.recordDate} 的体重记录吗？`, '删除记录', {
    type: 'warning',
    confirmButtonText: '删除',
    cancelButtonText: '取消',
  })
  await deleteHealth(record.id)
  ElMessage.success('记录已删除')
  await load()
}

const isToday = (date: string) => date === dayjs().format('YYYY-MM-DD')

/** 近 N 天打卡分布（柱状图，今天用绿色标出） */
const heatOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const base = baseChartStyle(tokens)
  const daily = heat.value

  return {
    textStyle: base.textStyle,
    grid: { left: 36, right: 14, top: 16, bottom: 24 },
    tooltip: {
      ...base.tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params: Array<{ dataIndex: number }>) => {
        const item = daily[params[0]?.dataIndex ?? 0]
        if (!item) return ''
        return `${item.date}<br/>打卡 <b>${item.count}</b> 次`
      },
    },
    xAxis: {
      type: 'category',
      data: daily.map((item) => item.date.slice(5)),
      axisLine: { lineStyle: { color: tokens.border } },
      axisTick: { show: false },
      axisLabel: base.axisLabel,
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: base.splitLine,
      axisLabel: base.axisLabel,
    },
    series: [
      {
        type: 'bar',
        barWidth: '46%',
        data: daily.map((item) => ({
          value: item.count,
          itemStyle: {
            color: isToday(item.date) ? tokens.secondary : tokens.primary,
            borderRadius: [4, 4, 0, 0],
          },
        })),
      },
    ],
  }
})

onMounted(load)
</script>

<template>
  <section class="habits-page">
    <header class="page-heading">
      <div>
        <p>HABITS &amp; HEALTH</p>
        <h2>习惯健康</h2>
        <span>打卡养成习惯，记录看见变化。</span>
      </div>
      <div class="heading-actions">
        <el-button @click="openHealth()"><el-icon><TrendCharts /></el-icon>记录体重</el-button>
        <el-button type="primary" @click="openHabit()"><el-icon><Plus /></el-icon>新增习惯</el-button>
      </div>
    </header>

    <div class="summary-grid">
      <div class="summary-card">
        <span class="summary-icon primary"><el-icon><Check /></el-icon></span>
        <div>
          <small>今日打卡</small>
          <strong>{{ stats?.today.checked ?? 0 }}<em>/{{ stats?.today.total ?? 0 }}</em></strong>
          <span class="summary-note">完成率 {{ stats?.today.rate ?? 0 }}%</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon secondary"><el-icon><Sunny /></el-icon></span>
        <div>
          <small>本周完成率</small>
          <strong>{{ stats?.week.rate ?? 0 }}<em>%</em></strong>
          <span class="summary-note">{{ stats?.week.checked ?? 0 }}/{{ stats?.week.possible ?? 0 }} 次</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon warning"><el-icon><TrendCharts /></el-icon></span>
        <div>
          <small>最长连续</small>
          <strong>{{ stats?.longestStreak ?? 0 }}<em>天</em></strong>
          <span class="summary-note">当前最长打卡记录</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon accent"><el-icon><Check /></el-icon></span>
        <div>
          <small>近 {{ stats?.days ?? 14 }} 天打卡</small>
          <strong>{{ stats?.totalChecked ?? 0 }}<em>次</em></strong>
          <span class="summary-note">
            {{ latest ? `体重 ${Number(latest.weight).toFixed(1)} kg` : '暂无体重记录' }}
          </span>
        </div>
      </div>
    </div>

    <section v-loading="loading" class="panel">
      <header class="panel-head">
        <div>
          <h3>今日打卡</h3>
          <p>点击卡片右侧按钮打卡，再点一次可取消</p>
        </div>
        <el-button text @click="openHabit()"><el-icon><Plus /></el-icon>新增习惯</el-button>
      </header>

      <div v-if="!habitCards.length" class="empty-block">
        <span class="empty-icon"><el-icon><Sunny /></el-icon></span>
        <strong>还没有习惯，先加一个吧</strong>
        <p>比如「早起」「阅读 30 分钟」「运动」</p>
        <el-button type="primary" @click="openHabit()"><el-icon><Plus /></el-icon>新增习惯</el-button>
      </div>

      <div v-else class="habit-grid">
        <article
          v-for="habit in habitCards"
          :key="habit.id"
          class="habit-card"
          :class="{ 'is-checked': habit.checkedToday }"
        >
          <div class="habit-main">
            <span class="habit-icon">{{ habit.icon }}</span>
            <div class="habit-copy">
              <strong>{{ habit.name }}</strong>
              <span>连续 {{ habit.streakDays }} 天 · 本周 {{ habit.weekCount }}/7</span>
            </div>
            <div class="habit-actions">
              <el-button text size="small" @click="openHabit(habit)"><el-icon><Edit /></el-icon></el-button>
              <el-button text size="small" type="danger" @click="removeHabit(habit)">
                <el-icon><Delete /></el-icon>
              </el-button>
            </div>
          </div>

          <div class="habit-week">
            <span
              v-for="day in habit.recent"
              :key="day.date"
              class="week-dot"
              :class="{ on: day.checked }"
              :title="day.date"
            >
              {{ dayjs(day.date).format('dd').slice(0, 1) }}
            </span>
          </div>

          <el-button
            class="habit-check"
            :type="habit.checkedToday ? 'success' : 'primary'"
            :plain="habit.checkedToday"
            @click="toggleCheck(habit)"
          >
            <el-icon><Check /></el-icon>
            {{ habit.checkedToday ? '已打卡' : '打卡' }}
          </el-button>
        </article>
      </div>

      <div v-if="heat.length" class="heat-strip">
        <div class="heat-head">
          <span>近 {{ heat.length }} 天打卡分布</span>
          <span class="heat-legend">今天用绿色标出</span>
        </div>
        <BaseChart :option="heatOption" :height="170" :aria-label="`近 ${heat.length} 天打卡分布`" />
      </div>
    </section>

    <section v-loading="loading" class="panel">
      <header class="panel-head">
        <div>
          <h3>健康体重</h3>
          <p>最近 30 次体重记录与变化趋势</p>
        </div>
        <el-button text @click="openHealth()"><el-icon><Plus /></el-icon>记录体重</el-button>
      </header>

      <div class="health-body">
        <div class="health-chart">
          <WeightChart :records="chartRecords" :height="200" />
        </div>

        <div class="health-stats">
          <div class="health-stat">
            <small>最新体重</small>
            <strong>{{ latest ? Number(latest.weight).toFixed(1) : '—' }}<em>kg</em></strong>
            <span :class="['delta', deltaClass(lastDelta)]">{{ deltaText(lastDelta) }}</span>
          </div>
          <div class="health-stat">
            <small>近 30 次变化</small>
            <strong>{{ windowDelta === null ? '—' : deltaText(windowDelta).replace(' kg', '') }}<em v-if="windowDelta !== null">kg</em></strong>
            <span class="delta flat">区间 {{ windowRange ? `${windowRange.min} ~ ${windowRange.max}` : '—' }}</span>
          </div>
          <div class="health-stat">
            <small>记录条数</small>
            <strong>{{ healthRecords.length }}<em>条</em></strong>
            <span class="delta flat">
              {{ healthRecords.length ? `平均 ${(healthRecords.reduce((sum, item) => sum + Number(item.weight), 0) / healthRecords.length).toFixed(1)} kg` : '暂无数据' }}
            </span>
          </div>
        </div>
      </div>

      <div v-if="healthList.length" class="health-list">
        <article v-for="(record, index) in healthList" :key="record.id" class="health-row">
          <span class="health-date">{{ record.recordDate }}</span>
          <strong class="health-weight">{{ Number(record.weight).toFixed(1) }} kg</strong>
          <span :class="['delta', deltaClass(deltaOf(record, index))]">{{ deltaText(deltaOf(record, index)) }}</span>
          <div class="health-actions">
            <el-button text size="small" @click="openHealth(record)"><el-icon><Edit /></el-icon>编辑</el-button>
            <el-button text size="small" type="danger" @click="removeHealth(record)">
              <el-icon><Delete /></el-icon>删除
            </el-button>
          </div>
        </article>
      </div>

      <div v-else class="empty-block small">
        <strong>还没有体重记录</strong>
        <p>记下今天的体重，明天就能看到变化</p>
        <el-button type="primary" @click="openHealth()"><el-icon><Plus /></el-icon>记录体重</el-button>
      </div>
    </section>

    <HabitFormDialog v-model="habitDialog" :habit="editingHabit" :saving="saving" @save="saveHabit" />
    <HealthFormDialog v-model="healthDialog" :record="editingHealth" :saving="saving" @save="saveHealth" />
  </section>
</template>

<style scoped lang="scss">
.habits-page {
  display: grid;
  gap: 18px;
  animation: habits-in 0.35s ease both;
}

@keyframes habits-in {
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
  gap: 10px;
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

.habit-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(248px, 1fr));
  gap: 13px;
}

.habit-card {
  display: grid;
  gap: 11px;
  padding: 14px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
  transition: all 0.2s ease;
}

.habit-card.is-checked {
  border-color: color-mix(in srgb, var(--secondary) 35%, var(--border-color));
  background: color-mix(in srgb, var(--secondary-soft) 55%, var(--surface));
}

.habit-main {
  display: flex;
  align-items: center;
  gap: 11px;
}

.habit-icon {
  display: grid;
  width: 40px;
  height: 40px;
  flex: none;
  place-items: center;
  border-radius: 12px;
  background: var(--surface);
  font-size: 20px;
  box-shadow: var(--shadow-xs);
}

.habit-copy {
  min-width: 0;
  flex: 1;
}

.habit-copy strong {
  display: block;
  overflow: hidden;
  color: var(--text-primary);
  font-size: 14px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.habit-copy span {
  display: block;
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 12px;
}

.habit-actions {
  display: flex;
  flex: none;
}

.habit-actions :deep(.el-button) {
  margin-left: 0;
  padding: 4px;
}

.habit-week {
  display: flex;
  gap: 5px;
}

.week-dot {
  display: grid;
  width: 24px;
  height: 24px;
  place-items: center;
  border: 1px solid var(--border-soft);
  border-radius: 8px;
  color: var(--text-secondary);
  background: var(--surface);
  font-size: 12px;
}

.week-dot.on {
  border-color: transparent;
  color: #fff;
  background: var(--primary);
}

.habit-check {
  width: 100%;
}

.heat-strip {
  margin-top: 18px;
  padding-top: 15px;
  border-top: 1px dashed var(--border-soft);
}

.heat-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 6px;
  color: var(--text-secondary);
  font-size: 13px;
}

.heat-legend {
  font-size: 12px;
  opacity: 0.8;
}

.health-body {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr);
  gap: 18px;
  align-items: center;
}

.health-chart {
  padding: 12px 14px 8px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.health-stats {
  display: grid;
  gap: 10px;
}

.health-stat {
  padding: 11px 13px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.health-stat small {
  display: block;
  color: var(--text-secondary);
  font-size: 12px;
}

.health-stat strong {
  display: block;
  margin-top: 4px;
  color: var(--text-primary);
  font-size: 20px;
}

.health-stat strong em {
  margin-left: 2px;
  color: var(--text-secondary);
  font-size: 13px;
  font-style: normal;
}

.delta {
  display: inline-block;
  margin-top: 5px;
  padding: 1px 8px;
  border-radius: 99px;
  font-size: 12px;
}

.delta.down {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.delta.up {
  color: var(--danger);
  background: color-mix(in srgb, var(--danger) 12%, transparent);
}

.delta.flat {
  color: var(--text-secondary);
  background: var(--surface);
}

.health-list {
  display: grid;
  gap: 8px;
  margin-top: 16px;
}

.health-row {
  display: grid;
  grid-template-columns: 130px 110px 100px auto;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
}

.health-date {
  color: var(--text-secondary);
  font-size: 13px;
}

.health-weight {
  color: var(--text-primary);
  font-size: 14px;
}

.health-actions {
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

.empty-block.small {
  padding: 24px 20px;
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

@media (max-width: 1080px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .health-body {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .summary-grid {
    grid-template-columns: 1fr;
  }

  .health-row {
    grid-template-columns: 1fr auto;
  }

  .health-row .delta {
    display: none;
  }

  .health-actions {
    grid-column: span 2;
    justify-content: flex-end;
  }
}
</style>

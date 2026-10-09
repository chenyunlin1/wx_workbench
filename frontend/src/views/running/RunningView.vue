<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import dayjs from 'dayjs'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  CircleCheck,
  CircleClose,
  Link,
  Refresh,
  Right,
  TrendCharts,
} from '@element-plus/icons-vue'
import {
  disconnectCoros,
  getCorosDashboard,
  getCorosStatus,
  startCorosConnect,
  startCorosSync,
} from '@/api/coros'
import { listWorkouts } from '@/api/workout'
import BaseChart from '@/components/charts/BaseChart.vue'
import { useThemeStore } from '@/stores/theme'
import { axisName, baseChartStyle, chartTokens, legendFrame, withAlpha } from '@/utils/echarts'
import {
  CATEGORY_EMOJI,
  RUNNING_QUESTIONS,
  formatDuration,
  formatMinutes,
  formatPace,
  loadCommentOf,
  loadToneOf,
  paceSeconds,
  predictionLabelOf,
  recoveryLevelOf,
  sportNameOf,
} from './running-meta'
import type {
  CorosActivityRow,
  CorosDailyRow,
  CorosDashboard,
  CorosStatus,
  Workout,
} from '@/types'

const WINDOW_OPTIONS = [
  { label: '近 7 天', value: 7 },
  { label: '近 30 天', value: 30 },
  { label: '近 90 天', value: 90 },
]

/** 跑量柱状图超过这个条数就按周汇总，否则一天一根柱子挤不下 */
const RUN_BAR_LIMIT = 14

const route = useRoute()
const router = useRouter()
const themeStore = useThemeStore()

const coros = ref<CorosStatus | null>(null)
const board = ref<CorosDashboard | null>(null)
const workouts = ref<Workout[]>([])
const windowDays = ref(30)
const loading = ref(false)
const connecting = ref(false)
const syncing = ref(false)

const loadStatus = async () => {
  coros.value = await getCorosStatus()
}

const loadDashboard = async () => {
  loading.value = true
  try {
    board.value = await getCorosDashboard(windowDays.value)
  } finally {
    loading.value = false
  }
}

const loadManualRuns = async () => {
  const from = dayjs().subtract(windowDays.value - 1, 'day').format('YYYY-MM-DD')
  const result = await listWorkouts({
    type: 'running',
    from,
    to: dayjs().format('YYYY-MM-DD'),
    page: 1,
    pageSize: 100,
  })
  workouts.value = [...result.items].sort(
    (left, right) => dayjs(left.workoutDate).valueOf() - dayjs(right.workoutDate).valueOf(),
  )
}

const reload = async () => {
  await Promise.all([loadDashboard(), loadManualRuns()])
}

/* ---------------- 同步：后端跑后台任务，前端轮询 status 看进度 ---------------- */

let pollTimer: ReturnType<typeof setInterval> | null = null

const stopPolling = () => {
  if (!pollTimer) return
  clearInterval(pollTimer)
  pollTimer = null
}

const pollUntilIdle = () =>
  new Promise<void>((resolve) => {
    stopPolling()
    pollTimer = setInterval(() => {
      void (async () => {
        try {
          const status = await getCorosStatus()
          coros.value = status
          if (status.sync.status !== 'running') {
            stopPolling()
            resolve()
          }
        } catch {
          stopPolling()
          resolve()
        }
      })()
    }, 3000)
  })

const syncLabel = computed(() => {
  const sync = coros.value?.sync
  if (sync?.status === 'running') return '同步中…'
  if (!sync?.syncedAt) return '同步高驰数据'
  return `同步于 ${dayjs(sync.syncedAt).format('MM-DD HH:mm')}`
})

const handleSync = async () => {
  if (syncing.value) return
  syncing.value = true
  try {
    await startCorosSync(windowDays.value)
    await loadStatus()
    await pollUntilIdle()
    await Promise.all([loadStatus(), reload()])

    const report = coros.value?.sync.result
    if (!report) {
      ElMessage.warning('同步没有正常结束，稍后再试一次')
    } else if (report.errors.length) {
      ElMessage.warning(
        `已同步 ${report.activities} 次运动、${report.daily} 天健康数据，${report.errors.length} 项取数失败`,
      )
    } else {
      ElMessage.success(
        `已同步 ${report.activities} 次运动、${report.daily} 天健康数据（${report.from} ~ ${report.to}）`,
      )
    }
  } finally {
    syncing.value = false
  }
}

/* ---------------- 授权 ---------------- */

/** 授权回跳由高驰直接打到后端 /coros/callback，处理完再 302 回这里，用 query 报结果 */
const reportRedirect = async () => {
  const state = route.query.coros
  if (typeof state !== 'string') return

  const message = typeof route.query.message === 'string' ? route.query.message : ''
  if (state === 'connected') {
    ElMessage.success(message || '高驰账号已连接，点「同步高驰数据」把跑步与身体数据拉进数据库')
  } else if (state === 'failed') {
    ElMessage.error(message || '高驰授权未完成')
  }

  await router.replace({ query: {} })
  await loadStatus()
}

const handleConnect = async () => {
  connecting.value = true
  try {
    const result = await startCorosConnect()
    // 同标签页跳授权页，回跳时高驰只会带着 code 回到后端回调地址
    window.location.href = result.authorizeUrl
  } catch {
    connecting.value = false
  }
}

const handleDisconnect = async () => {
  await ElMessageBox.confirm(
    '解绑后会撤销高驰侧的授权令牌，AI 助手将无法再读取手表数据；已经同步到本平台的历史数据会保留。',
    '解绑高驰账号',
    { type: 'warning', confirmButtonText: '解绑', cancelButtonText: '取消' },
  )
  await disconnectCoros()
  ElMessage.success('已解绑高驰账号')
  await loadStatus()
}

const askAi = (question: string) => {
  router.push({ path: '/ai', query: { ask: question } })
}

/* ---------------- 高驰数据的派生视图 ---------------- */

const activities = computed(() => board.value?.activities ?? [])
const daily = computed(() => board.value?.daily ?? [])
const runs = computed(() => activities.value.filter((item) => item.category === 'running'))
const hasCorosData = computed(() => activities.value.length > 0 || daily.value.length > 0)

/** 逐日数据按日期升序返回，从后往前找第一条真正有值的 */
function lastOf<T>(rows: T[], pick: (row: T) => boolean): T | null {
  for (let index = rows.length - 1; index >= 0; index -= 1) {
    if (pick(rows[index])) return rows[index]
  }
  return null
}

const stats = computed(() => {
  const measured = runs.value.filter((item) => Number(item.distanceKm) > 0)
  const distance = measured.reduce((sum, item) => sum + Number(item.distanceKm), 0)
  const seconds = runs.value.reduce((sum, item) => sum + item.durationSeconds, 0)

  return {
    sessions: runs.value.length,
    distance,
    hours: seconds / 3600,
    pace: distance > 0 ? seconds / distance : 0,
    longest: measured.reduce((max, item) => Math.max(max, Number(item.distanceKm)), 0),
    thisWeek: measured
      .filter((item) => dayjs().diff(dayjs(item.activityDate), 'day') < 7)
      .reduce((sum, item) => sum + Number(item.distanceKm), 0),
    activeDays: new Set(runs.value.map((item) => item.activityDate)).size,
  }
})

const loadRow = computed(() =>
  lastOf(daily.value, (row) => row.shortTermLoad !== null && row.loadComment !== null),
)
const sleepRow = computed(() =>
  lastOf(daily.value, (row) => row.sleepScore !== null && row.sleepScore > 0),
)
const hrvRow = computed(() => lastOf(daily.value, (row) => row.hrvMs !== null))
const heartRow = computed(() =>
  lastOf(daily.value, (row) => row.avgHr !== null || row.restingHr !== null),
)

const fitness = computed(() => board.value?.fitness ?? null)
const recovery = computed(() => board.value?.recovery ?? null)
const schedule = computed(() => board.value?.schedule?.items ?? [])
const syncErrors = computed(() => coros.value?.sync.result?.errors ?? [])

/* ---------------- 图表 ---------------- */

interface RunPoint {
  label: string
  distance: number
  paceSeconds: number
  sessions: number
}

/** 次数太多就按周汇总，周内的配速用「总时长 ÷ 总距离」而不是各次平均 */
const runPoints = computed<RunPoint[]>(() => {
  const list = runs.value.filter((item) => Number(item.distanceKm) > 0)
  if (!list.length) return []

  if (list.length <= RUN_BAR_LIMIT) {
    return list.map((item) => ({
      label: dayjs(item.activityDate).format('MM-DD'),
      distance: Number(item.distanceKm),
      paceSeconds: item.durationSeconds / Number(item.distanceKm),
      sessions: 1,
    }))
  }

  const weeks = new Map<string, { distance: number; seconds: number; sessions: number }>()
  for (const item of list) {
    const key = dayjs(item.activityDate).startOf('week').format('YYYY-MM-DD')
    const week = weeks.get(key) ?? { distance: 0, seconds: 0, sessions: 0 }
    week.distance += Number(item.distanceKm)
    week.seconds += item.durationSeconds
    week.sessions += 1
    weeks.set(key, week)
  }

  return [...weeks.entries()].map(([key, week]) => ({
    label: `${dayjs(key).format('MM-DD')} 周`,
    distance: Number(week.distance.toFixed(2)),
    paceSeconds: week.seconds / week.distance,
    sessions: week.sessions,
  }))
})

const baseOption = (tokens: ReturnType<typeof chartTokens>) => ({
  textStyle: baseChartStyle(tokens).textStyle,
  ...legendFrame(tokens),
})

const valueAxis = (
  tokens: ReturnType<typeof chartTokens>,
  name: string,
  extra: Record<string, unknown> = {},
) => ({
  type: 'value',
  name,
  ...axisName(tokens),
  axisLine: { show: false },
  axisTick: { show: false },
  splitLine: { lineStyle: { color: tokens.border, type: 'dashed' as const } },
  axisLabel: { color: tokens.muted, fontSize: 11 },
  ...extra,
})

const categoryAxis = (tokens: ReturnType<typeof chartTokens>, data: string[], interval: number) => ({
  type: 'category',
  data,
  axisLine: { lineStyle: { color: tokens.border } },
  axisTick: { show: false },
  axisLabel: { color: tokens.muted, fontSize: 11, interval },
})

const lineLook = (tokens: ReturnType<typeof chartTokens>, color: string) => ({
  lineStyle: { width: 2, color },
  itemStyle: { color, borderColor: tokens.surface, borderWidth: 2 },
})

/** 柱=距离，折线=配速（配速越低越快，读法交给 tooltip） */
const runOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const points = runPoints.value

  return {
    ...baseOption(tokens),
    tooltip: {
      ...baseChartStyle(tokens).tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow', shadowStyle: { color: withAlpha(tokens.primary, 0.06) } },
      formatter: (params: Array<{ dataIndex: number }>) => {
        const item = points[params[0]?.dataIndex ?? 0]
        if (!item) return ''
        return [
          `<div style="margin-bottom:4px">${item.label}</div>`,
          `<div>距离 <b>${item.distance.toFixed(2)}</b> 公里</div>`,
          `<div>平均配速 <b>${formatPace(item.paceSeconds)}</b> / 公里</div>`,
          `<div>跑步次数 <b>${item.sessions}</b> 次</div>`,
        ].join('')
      },
    },
    xAxis: categoryAxis(tokens, points.map((item) => item.label), points.length > 16 ? 1 : 0),
    yAxis: [valueAxis(tokens, '公里'), valueAxis(tokens, '分/公里', { splitLine: { show: false } })],
    series: [
      {
        name: '距离',
        type: 'bar',
        barMaxWidth: 18,
        data: points.map((item) => item.distance),
        itemStyle: { color: tokens.primary, borderRadius: [5, 5, 0, 0] },
      },
      {
        name: '配速',
        type: 'line',
        yAxisIndex: 1,
        smooth: true,
        symbol: 'circle',
        symbolSize: 7,
        data: points.map((item) => Number((item.paceSeconds / 60).toFixed(2))),
        ...lineLook(tokens, tokens.accent),
      },
    ],
  }
})

const dayLabels = (rows: CorosDailyRow[]) => rows.map((row) => dayjs(row.day).format('MM-DD'))

/** 睡眠时长 + 评分：没戴手表睡觉的那几天留空，不画成 0 分 */
const sleepOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const rows = daily.value

  return {
    ...baseOption(tokens),
    tooltip: {
      ...baseChartStyle(tokens).tooltip,
      trigger: 'axis',
      axisPointer: { type: 'shadow', shadowStyle: { color: withAlpha(tokens.secondary, 0.06) } },
      formatter: (params: Array<{ dataIndex: number }>) => {
        const row = rows[params[0]?.dataIndex ?? 0]
        if (!row) return ''
        const parts = [`<div style="margin-bottom:4px">${row.day}</div>`]
        parts.push(
          `<div>睡眠 <b>${row.mainSleepMinutes === null ? '暂无' : formatMinutes(row.mainSleepMinutes)}</b></div>`,
        )
        if (row.sleepScore !== null && row.sleepScore > 0) {
          parts.push(`<div>评分 <b>${row.sleepScore}</b></div>`)
        }
        if (row.deepRatio !== null) parts.push(`<div>深睡 <b>${row.deepRatio}%</b></div>`)
        if (row.remRatio !== null) parts.push(`<div>REM <b>${row.remRatio}%</b></div>`)
        if (row.napMinutes) parts.push(`<div>小睡 <b>${formatMinutes(row.napMinutes)}</b></div>`)
        if (row.sleepWindow) parts.push(`<div>${row.sleepWindow}</div>`)
        return parts.join('')
      },
    },
    xAxis: categoryAxis(tokens, dayLabels(rows), rows.length > 16 ? 2 : 0),
    yAxis: [
      valueAxis(tokens, '小时'),
      valueAxis(tokens, '评分', { max: 100, splitLine: { show: false } }),
    ],
    series: [
      {
        name: '睡眠时长',
        type: 'bar',
        barMaxWidth: 16,
        data: rows.map((row) =>
          row.mainSleepMinutes === null ? null : Number((row.mainSleepMinutes / 60).toFixed(2)),
        ),
        itemStyle: { color: tokens.secondary, borderRadius: [5, 5, 0, 0] },
      },
      {
        name: '睡眠评分',
        type: 'line',
        yAxisIndex: 1,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        connectNulls: true,
        data: rows.map((row) =>
          row.sleepScore === null || row.sleepScore < 0 ? null : row.sleepScore,
        ),
        ...lineLook(tokens, tokens.accent),
      },
    ],
  }
})

/** 平均/静息心率与短期训练负荷 */
const heartOption = computed(() => {
  void themeStore.theme
  const tokens = chartTokens()
  const rows = daily.value

  return {
    ...baseOption(tokens),
    tooltip: {
      ...baseChartStyle(tokens).tooltip,
      trigger: 'axis',
      axisPointer: { type: 'line', lineStyle: { color: tokens.border, type: 'dashed' } },
      formatter: (params: Array<{ dataIndex: number }>) => {
        const row = rows[params[0]?.dataIndex ?? 0]
        if (!row) return ''
        return [
          `<div style="margin-bottom:4px">${row.day}</div>`,
          `<div>平均心率 <b>${row.avgHr ?? '暂无'}</b> bpm</div>`,
          `<div>静息心率 <b>${row.restingHr ?? '暂无'}</b> bpm</div>`,
          `<div>最高 / 最低 <b>${row.maxHr ?? '—'} / ${row.minHr ?? '—'}</b> bpm</div>`,
          `<div>短期负荷 <b>${row.shortTermLoad ?? '暂无'}</b></div>`,
          `<div>步数 <b>${row.steps ?? '暂无'}</b></div>`,
        ].join('')
      },
    },
    xAxis: categoryAxis(tokens, dayLabels(rows), rows.length > 16 ? 2 : 0),
    yAxis: [valueAxis(tokens, 'bpm'), valueAxis(tokens, '负荷', { splitLine: { show: false } })],
    series: [
      {
        name: '平均心率',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: rows.map((row) => row.avgHr),
        lineStyle: { width: 2, color: tokens.rose },
        areaStyle: { color: withAlpha(tokens.rose, 0.1) },
      },
      {
        name: '静息心率',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: rows.map((row) => row.restingHr),
        lineStyle: { width: 2, color: tokens.cyan },
      },
      {
        name: '短期负荷',
        type: 'bar',
        yAxisIndex: 1,
        barMaxWidth: 12,
        data: rows.map((row) => row.shortTermLoad),
        itemStyle: { color: withAlpha(tokens.primary, 0.45), borderRadius: [4, 4, 0, 0] },
      },
    ],
  }
})

/* ---------------- 本平台手记（手动记录，与高驰数据分开存放） ---------------- */

const manualSummary = computed(() => {
  const withDistance = workouts.value.filter((item) => Number(item.distance) > 0)
  const distance = withDistance.reduce((sum, item) => sum + Number(item.distance), 0)
  const minutes = workouts.value.reduce((sum, item) => sum + item.duration, 0)

  return {
    sessions: workouts.value.length,
    distance,
    minutes,
    pace: distance > 0 ? (minutes * 60) / distance : 0,
  }
})

const recentActivities = computed<CorosActivityRow[]>(() =>
  [...activities.value].reverse().slice(0, 30),
)

const latestDaily = computed(() => daily.value[daily.value.length - 1] ?? null)

onMounted(async () => {
  await Promise.all([loadStatus(), loadManualRuns()])
  await reportRedirect()

  if (!coros.value?.connected) return
  await loadDashboard()

  // 别的标签页正在同步时接着轮询，结束后再刷新面板
  if (coros.value.sync.status === 'running') {
    syncing.value = true
    await pollUntilIdle()
    syncing.value = false
    await Promise.all([loadStatus(), loadDashboard()])
  }
})

onBeforeUnmount(stopPolling)
</script>

<template>
  <section class="running-page">
    <header class="page-heading">
      <div>
        <p>RUNNING</p>
        <h2>跑步专项</h2>
        <span>高驰官方 MCP 的数据同步进本库，页面与 AI 助手读同一份记录。</span>
      </div>
      <div class="heading-actions">
        <el-radio-group v-model="windowDays" class="window-switch" @change="coros?.connected && reload()">
          <el-radio-button v-for="item in WINDOW_OPTIONS" :key="item.value" :value="item.value">
            {{ item.label }}
          </el-radio-button>
        </el-radio-group>
        <el-button
          type="primary"
          plain
          :loading="syncing"
          :disabled="!coros?.connected"
          @click="handleSync"
        >
          <el-icon><Refresh /></el-icon>{{ syncLabel }}
        </el-button>
        <el-button @click="askAi('我这周的跑量和配速怎么样？和上周相比如何')">
          <el-icon><TrendCharts /></el-icon>问问 AI
        </el-button>
      </div>
    </header>

    <section class="panel connect-panel">
      <template v-if="!coros?.connected">
        <div class="connect-copy">
          <span class="connect-icon"><el-icon><Link /></el-icon></span>
          <div>
            <h3>还没有连接高驰</h3>
            <p>
              授权后可以把手表侧的运动记录、配速、心率、睡眠、HRV、压力与恢复程度同步到本平台数据库，
              AI 助手也会直接读这些真实数据来回答。
            </p>
            <small>接口地址 {{ coros?.endpoint || 'https://mcp.coros.com/mcp' }} · OAuth 2.1 授权码 + PKCE</small>
          </div>
        </div>
        <el-button type="primary" :loading="connecting" @click="handleConnect">
          <el-icon><Link /></el-icon>连接高驰账号
        </el-button>
      </template>

      <template v-else>
        <div class="connect-copy">
          <span class="connect-icon ok"><el-icon><CircleCheck /></el-icon></span>
          <div>
            <h3>已连接高驰</h3>
            <p>
              账号 {{ coros.account || '未知' }} · {{ coros.toolCount }} 个工具可用
              <template v-if="coros.sync.syncedAt">
                · 数据同步于 {{ dayjs(coros.sync.syncedAt).format('MM-DD HH:mm') }}
              </template>
              <template v-if="coros.expiresAt">
                · 授权有效期至 {{ dayjs(coros.expiresAt).format('YYYY-MM-DD') }}
              </template>
            </p>
            <small v-if="coros.sync.result">
              最近一次同步窗口 {{ coros.sync.result.from }} ~ {{ coros.sync.result.to }} ·
              {{ coros.sync.result.activities }} 条运动 · {{ coros.sync.result.daily }} 天健康数据 ·
              {{ coros.sync.result.details }} 条含详细字段 · 耗时
              {{ (coros.sync.result.durationMs / 1000).toFixed(1) }} 秒
            </small>
            <small v-else>还没有同步过数据，点「同步高驰数据」把最近的记录拉进数据库。</small>
          </div>
        </div>
        <div class="connect-actions">
          <el-button size="small" :loading="syncing" @click="handleSync">
            <el-icon><Refresh /></el-icon>同步数据
          </el-button>
          <el-button size="small" @click="handleConnect">重新授权</el-button>
          <el-button size="small" type="danger" plain @click="handleDisconnect">
            <el-icon><CircleClose /></el-icon>解绑
          </el-button>
        </div>
      </template>
    </section>

    <p v-if="syncErrors.length" class="panel sync-warning">
      这次有 {{ syncErrors.length }} 项数据没取到：{{ syncErrors.map((item) => item.tool).join('、') }}
      （其余数据不受影响）
    </p>

    <section
      v-if="coros?.connected && !hasCorosData"
      v-loading="loading"
      class="panel empty-block"
    >
      <span class="empty-icon"><el-icon><TrendCharts /></el-icon></span>
      <strong>还没有同步过高驰数据</strong>
      <p>
        同步会把运动记录、每日健康、睡眠、HRV、训练负荷与恢复状态写进本地数据库，
        之后这个页面和 AI 助手都读同一份，不必每问一句就去请求高驰。
      </p>
      <el-button type="primary" :loading="syncing" @click="handleSync">
        <el-icon><Refresh /></el-icon>同步高驰数据
      </el-button>
    </section>

    <template v-if="hasCorosData">
      <div v-loading="loading" class="summary-grid">
        <div class="summary-card">
          <span class="summary-icon primary"><el-icon><TrendCharts /></el-icon></span>
          <div>
            <small>恢复程度</small>
            <strong>{{ recovery?.recoveryPct ?? '—' }}<em v-if="recovery?.recoveryPct">%</em></strong>
            <span class="summary-note">
              {{ recoveryLevelOf(recovery?.level ?? null) || '暂无恢复数据' }}
              <template v-if="recovery?.fullRecoveryHours">
                · 约 {{ recovery.fullRecoveryHours }} 小时恢复
              </template>
            </span>
          </div>
        </div>

        <div class="summary-card">
          <span class="summary-icon" :class="`tone-${loadToneOf(loadRow?.loadComment ?? null)}`">
            <el-icon><TrendCharts /></el-icon>
          </span>
          <div>
            <small>训练负荷</small>
            <strong>{{ loadRow?.shortTermLoad ?? '—' }}<em v-if="loadRow">短期</em></strong>
            <span class="summary-note">
              长期 {{ loadRow?.longTermLoad ?? '—' }} · 比值 {{ loadRow?.loadRatio ?? '—' }} ·
              {{ loadCommentOf(loadRow?.loadComment ?? null) || '暂无评估' }}
            </span>
          </div>
        </div>

        <div class="summary-card">
          <span class="summary-icon accent"><el-icon><TrendCharts /></el-icon></span>
          <div>
            <small>体能评估</small>
            <strong>{{ fitness?.vo2max ?? '—' }}<em v-if="fitness?.vo2max">VO2max</em></strong>
            <span class="summary-note">
              跑步等级 {{ fitness?.runningLevel ?? '—' }} · 阈值配速
              {{
                fitness?.thresholdPaceSeconds
                  ? `${formatPace(fitness.thresholdPaceSeconds)}/公里`
                  : '—'
              }}
            </span>
          </div>
        </div>

        <div class="summary-card">
          <span class="summary-icon secondary"><el-icon><TrendCharts /></el-icon></span>
          <div>
            <small>本窗口跑量</small>
            <strong>{{ stats.distance.toFixed(1) }}<em>公里</em></strong>
            <span class="summary-note">
              {{ stats.sessions }} 次 ·
              {{ stats.pace > 0 ? `${formatPace(stats.pace)}/公里` : '—' }} · 近 7 天
              {{ stats.thisWeek.toFixed(1) }} 公里
            </span>
          </div>
        </div>
      </div>

      <div class="grid-2">
        <section class="panel">
          <header class="panel-head">
            <div>
              <h3>未来计划</h3>
              <p>高驰课表里排在后面的训练</p>
            </div>
          </header>

          <div v-if="schedule.length" class="plan-list">
            <article v-for="item in schedule" :key="`${item.date}-${item.name}`" class="plan-row">
              <div class="plan-date">
                <strong>{{ dayjs(item.date).format('MM-DD') }}</strong>
                <span>周{{ '日一二三四五六'[dayjs(item.date).day()] }}</span>
              </div>
              <div class="plan-main">
                <strong>{{ item.name }}</strong>
                <span>
                  {{ item.distanceKm !== null ? `${item.distanceKm.toFixed(2)} 公里` : '距离未定' }}
                  <template v-if="item.estimatedSeconds">
                    · 约 {{ formatDuration(item.estimatedSeconds) }}
                  </template>
                </span>
              </div>
              <span v-if="item.loadTl !== null" class="chip">负荷 {{ item.loadTl }}</span>
            </article>
          </div>
          <div v-else class="chart-empty">高驰课表里暂时没有排好的训练</div>
        </section>

        <section class="panel">
          <header class="panel-head">
            <div>
              <h3>成绩预测</h3>
              <p>高驰按当前体能给出的预估</p>
            </div>
            <el-button
              text
              size="small"
              @click="askAi('按我现在的体能，这些预测成绩合理吗？要怎么练才能提高')"
            >
              <el-icon><Right /></el-icon>问 AI
            </el-button>
          </header>

          <div v-if="fitness?.predictions.length" class="predict-grid">
            <div v-for="item in fitness.predictions" :key="item.label" class="predict-card">
              <small>{{ predictionLabelOf(item.label) }}</small>
              <strong>{{ formatDuration(item.seconds) }}</strong>
            </div>
          </div>
          <div v-else class="chart-empty">还没有成绩预测，先去高驰做一次跑步能力测试</div>

          <div v-if="daily.length" class="inline-stats">
            <span>静息心率 <b>{{ heartRow?.restingHr ?? '暂无' }}</b> bpm</span>
            <span>睡眠 <b>{{ sleepRow ? formatMinutes(sleepRow.mainSleepMinutes) : '暂无' }}</b></span>
            <span>HRV <b>{{ hrvRow?.hrvMs ?? '暂无' }}</b> ms</span>
            <span>步数 <b>{{ latestDaily?.steps ?? '暂无' }}</b></span>
          </div>
        </section>
      </div>

      <section v-loading="loading" class="panel">
        <header class="panel-head">
          <div>
            <h3>跑量趋势</h3>
            <p>
              {{ runPoints.length > RUN_BAR_LIMIT ? '按周汇总' : '按每次跑步' }} · 共
              {{ stats.sessions }} 次 · 最长单次 {{ stats.longest.toFixed(2) }} 公里 · 累计
              {{ stats.hours.toFixed(1) }} 小时 · 活跃 {{ stats.activeDays }} 天
            </p>
          </div>
        </header>

        <BaseChart
          v-if="runPoints.length"
          :option="runOption"
          :height="240"
          aria-label="跑量与配速趋势"
        />
        <div v-else class="chart-empty">这个窗口里高驰没有跑步记录</div>
      </section>

      <div class="grid-2">
        <section v-loading="loading" class="panel">
          <header class="panel-head">
            <div>
              <h3>睡眠</h3>
              <p>按「醒来那天」计，没戴手表睡觉的日子留空</p>
            </div>
          </header>

          <BaseChart
            v-if="daily.length"
            :option="sleepOption"
            :height="220"
            aria-label="睡眠时长与评分"
          />
          <div v-else class="chart-empty">还没有同步到睡眠数据</div>
        </section>

        <section v-loading="loading" class="panel">
          <header class="panel-head">
            <div>
              <h3>心率与训练负荷</h3>
              <p>平均心率、静息心率与短期训练负荷</p>
            </div>
          </header>

          <BaseChart
            v-if="daily.length"
            :option="heartOption"
            :height="220"
            aria-label="心率与训练负荷"
          />
          <div v-else class="chart-empty">还没有同步到心率数据</div>
        </section>
      </div>

      <section class="panel">
        <header class="panel-head">
          <div>
            <h3>高驰运动记录</h3>
            <p>共 {{ activities.length }} 条 · 近 {{ windowDays }} 天，最近的记录含训练负荷等详细字段</p>
          </div>
        </header>

        <div class="record-list">
          <article v-for="row in recentActivities" :key="row.id" class="record-row">
            <span class="record-emoji">{{ CATEGORY_EMOJI[row.category] }}</span>
            <div class="record-main">
              <strong>{{ row.name || sportNameOf(row.sportName) }}</strong>
              <span>{{ sportNameOf(row.sportName) }}</span>
            </div>
            <div class="record-meta">
              <span v-if="Number(row.distanceKm) > 0" class="chip">
                {{ Number(row.distanceKm).toFixed(2) }} 公里
              </span>
              <span v-if="row.paceSeconds" class="chip">{{ formatPace(row.paceSeconds) }}/公里</span>
              <span class="chip">{{ Math.round(row.durationSeconds / 60) }} 分钟</span>
              <span v-if="row.avgHr" class="chip">{{ row.avgHr }} bpm</span>
              <span v-if="row.trainingLoad" class="chip">负荷 {{ row.trainingLoad }}</span>
              <span v-if="row.avgCadence" class="chip">步频 {{ row.avgCadence }}</span>
              <span v-if="row.avgPower" class="chip">{{ row.avgPower }} W</span>
              <span v-if="row.elevationGain" class="chip">爬升 {{ row.elevationGain }} m</span>
              <span v-if="row.trainingFocus" class="chip">{{ row.trainingFocus }}</span>
              <span v-if="row.performance" class="chip">{{ row.performance }}</span>
            </div>
            <span class="record-date">{{ dayjs(row.activityDate).format('MM-DD HH:mm') }}</span>
          </article>
        </div>
      </section>
    </template>

    <div class="grid-2">
      <section class="panel">
        <header class="panel-head">
          <div>
            <h3>{{ hasCorosData ? '可以这样问 AI' : '连上高驰后可以这样问' }}</h3>
            <p>点一句直接带去 AI 助手，它会现场调用高驰工具补充细节</p>
          </div>
        </header>

        <ul class="question-list">
          <li v-for="item in RUNNING_QUESTIONS" :key="item">
            <button type="button" @click="askAi(item)">
              <span>{{ item }}</span>
              <el-icon><Right /></el-icon>
            </button>
          </li>
        </ul>

        <p v-if="!coros?.connected" class="panel-tip">
          未连接高驰时，AI 只能看到本平台手记的跑步记录，配速、心率、睡眠这些手表侧的数据要连接后才能读到。
        </p>
      </section>

      <section v-loading="loading" class="panel">
        <header class="panel-head">
          <div>
            <h3>本平台手记</h3>
            <p>手动记录的跑步，与高驰同步的数据分开存放</p>
          </div>
          <el-button text size="small" @click="router.push('/fitness')">
            <el-icon><TrendCharts /></el-icon>去「减脂健身」记录
          </el-button>
        </header>

        <div class="inline-stats">
          <span>{{ manualSummary.sessions }} 次</span>
          <span>{{ manualSummary.distance.toFixed(1) }} 公里</span>
          <span>{{ manualSummary.minutes }} 分钟</span>
          <span>
            平均配速
            {{ manualSummary.pace > 0 ? `${formatPace(manualSummary.pace)}/公里` : '—' }}
          </span>
        </div>

        <div v-if="!workouts.length" class="chart-empty">
          还没有手动记录过跑步，可在「减脂健身」里补一条类型为「跑步」的训练
        </div>
        <div v-else class="record-list">
          <article v-for="run in [...workouts].reverse().slice(0, 8)" :key="run.id" class="record-row">
            <span class="record-emoji">🏃</span>
            <div class="record-main">
              <strong>{{ run.title || '跑步' }}</strong>
              <span>{{ run.note || '来自减脂健身的手记记录' }}</span>
            </div>
            <div class="record-meta">
              <span v-if="Number(run.distance) > 0" class="chip">
                {{ Number(run.distance).toFixed(2) }} 公里
              </span>
              <span class="chip">{{ run.duration }} 分钟</span>
              <span v-if="Number(run.distance) > 0" class="chip">
                {{ formatPace(paceSeconds(run)) }}/公里
              </span>
              <span v-if="run.calories" class="chip">{{ run.calories }} 千卡</span>
            </div>
            <span class="record-date">{{ dayjs(run.workoutDate).format('MM-DD HH:mm') }}</span>
          </article>
        </div>
      </section>
    </div>
  </section>
</template>

<style scoped lang="scss">
.running-page {
  display: grid;
  gap: 18px;
  animation: running-in 0.35s ease both;
}

@keyframes running-in {
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

.panel {
  padding: 18px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.panel-head {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}

.panel-head h3 {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: var(--text-primary);
  font-size: 15px;
}

.panel-head p {
  margin: 5px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.panel-tip {
  padding: 10px 12px;
  margin: 12px 0 0;
  border-radius: 10px;
  color: var(--text-secondary);
  background: var(--surface-muted);
  font-size: 12px;
  line-height: 1.6;
}

.sync-warning {
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 10%, var(--surface-raised));
  font-size: 12px;
}

.connect-panel {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  align-items: center;
  justify-content: space-between;
}

.connect-copy {
  display: flex;
  gap: 14px;
  align-items: flex-start;
  min-width: 260px;
  flex: 1;
}

.connect-icon {
  display: grid;
  width: 44px;
  height: 44px;
  flex: none;
  place-items: center;
  border-radius: 13px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 20px;
}

.connect-icon.ok {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.connect-copy h3 {
  margin: 0 0 6px;
  color: var(--text-primary);
  font-size: 16px;
}

.connect-copy p {
  margin: 0;
  color: var(--text-regular);
  font-size: 13px;
  line-height: 1.7;
}

.connect-copy small {
  display: block;
  margin-top: 6px;
  color: var(--text-secondary);
  font-size: 12px;
}

.connect-actions {
  display: flex;
  gap: 8px;
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

.summary-icon.accent {
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 14%, transparent);
}

.summary-icon.tone-ok {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.summary-icon.tone-warn {
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, transparent);
}

.summary-icon.tone-bad {
  color: var(--danger);
  background: color-mix(in srgb, var(--danger) 14%, transparent);
}

.summary-icon.tone-muted {
  color: var(--text-secondary);
  background: var(--surface-muted);
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
  font-weight: 800;
  letter-spacing: -0.02em;
}

.summary-card strong em {
  margin-left: 4px;
  color: var(--text-secondary);
  font-size: 12px;
  font-style: normal;
  font-weight: 600;
}

.summary-note {
  display: block;
  margin-top: 5px;
  color: var(--text-secondary);
  font-size: 12px;
}

.grid-2 {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.chart-empty {
  display: grid;
  min-height: 150px;
  place-items: center;
  border-radius: 12px;
  background: var(--surface-muted);
  color: var(--text-secondary);
  font-size: 13px;
  text-align: center;
}

.plan-row {
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr) auto;
  gap: 12px;
  align-items: center;
  padding: 12px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
}

.plan-date {
  text-align: center;
}

.plan-date strong {
  display: block;
  color: var(--text-primary);
  font-size: 14px;
}

.plan-date span {
  color: var(--text-secondary);
  font-size: 11px;
}

.plan-main strong {
  display: block;
  color: var(--text-primary);
  font-size: 14px;
}

.plan-main span {
  display: block;
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.predict-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.predict-card {
  padding: 12px 8px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
  text-align: center;
}

.predict-card small {
  display: block;
  color: var(--text-secondary);
  font-size: 11px;
}

.predict-card strong {
  display: block;
  margin-top: 5px;
  color: var(--text-primary);
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.inline-stats {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 16px;
  margin-top: 12px;
  color: var(--text-secondary);
  font-size: 12px;
}

.inline-stats b {
  color: var(--text-primary);
}

.chip {
  padding: 2px 8px;
  border-radius: 99px;
  color: var(--text-secondary);
  background: var(--surface);
  border: 1px solid var(--border-soft);
  font-size: 11px;
  white-space: nowrap;
}

.question-list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.question-list button {
  display: flex;
  width: 100%;
  gap: 8px;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border: 1px solid var(--border-soft);
  border-radius: 11px;
  background: var(--surface-muted);
  color: var(--text-regular);
  font-size: 13px;
  text-align: left;
  cursor: pointer;
  transition: all 0.2s ease;
}

.question-list button:hover {
  border-color: var(--primary);
  color: var(--primary-strong);
  background: var(--primary-soft);
}

.record-list,
.plan-list {
  display: grid;
  gap: 10px;
  max-height: 420px;
  overflow-y: auto;
}

.record-row {
  display: grid;
  grid-template-columns: 34px minmax(0, 1.3fr) auto 92px;
  gap: 12px;
  align-items: center;
  padding: 12px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
}

.record-emoji {
  font-size: 20px;
  text-align: center;
}

.record-main strong {
  display: block;
  color: var(--text-primary);
  font-size: 14px;
}

.record-main span {
  display: block;
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.record-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.record-date {
  color: var(--text-secondary);
  font-size: 12px;
  text-align: right;
}

.empty-block {
  display: grid;
  gap: 10px;
  place-items: center;
  padding: 28px 0;
  text-align: center;
}

.empty-icon {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 14px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 22px;
}

.empty-block strong {
  color: var(--text-primary);
  font-size: 15px;
}

.empty-block p {
  margin: 0;
  max-width: 560px;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.7;
}

@media (max-width: 1180px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .grid-2,
  .predict-grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .record-row {
    grid-template-columns: 30px minmax(0, 1fr);
  }

  .record-meta,
  .record-date {
    grid-column: 2;
  }
}
</style>

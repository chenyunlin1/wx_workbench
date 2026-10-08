<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import dayjs, { type Dayjs } from 'dayjs'
import { ArrowLeft, ArrowRight, Bell, Calendar, Clock, Delete, Edit, Plus } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { createSchedule, deleteSchedule, listSchedules, updateSchedule } from '@/api/schedule'
import ScheduleFormDialog from './components/ScheduleFormDialog.vue'
import type { Schedule, ScheduleFormPayload } from '@/types'

type ViewMode = 'day' | 'week' | 'month'

const viewMode = ref<ViewMode>('month')
const currentDate = ref(dayjs())
const schedules = ref<Schedule[]>([])
const loading = ref(false)
const route = useRoute()
const router = useRouter()
/** 从别处带 ?category=面试 跳进来时只看这一个分类，关掉标签即恢复全部 */
const categoryFilter = ref(typeof route.query.category === 'string' ? route.query.category : '')
const dialogVisible = ref(false)
const editingSchedule = ref<Schedule | null>(null)
const defaultDate = ref('')
const saving = ref(false)
const expandedDays = ref<string[]>([])
const weekLabels = ['一', '二', '三', '四', '五', '六', '日']
const hours = Array.from({ length: 24 }, (_, index) => index)

const startOfWeek = (date: Dayjs) => {
  const day = date.day()
  return date.add(day === 0 ? -6 : 1 - day, 'day').startOf('day')
}

const gridStart = computed(() => {
  const first = currentDate.value.startOf('month')
  const day = first.day()
  return first.add(day === 0 ? -6 : 1 - day, 'day')
})

const range = computed(() => {
  if (viewMode.value === 'day') return { start: currentDate.value.startOf('day'), end: currentDate.value.add(1, 'day').startOf('day') }
  if (viewMode.value === 'week') {
    const start = startOfWeek(currentDate.value)
    return { start, end: start.add(7, 'day') }
  }
  return { start: gridStart.value, end: gridStart.value.add(42, 'day') }
})

const navigationLabel = computed(() => {
  if (viewMode.value === 'day') return currentDate.value.format('YYYY年M月D日')
  if (viewMode.value === 'week') {
    const start = startOfWeek(currentDate.value)
    const end = start.add(6, 'day')
    return start.month() === end.month()
      ? start.format('YYYY年M月D日') + ' - ' + end.format('D日')
      : start.format('YYYY年M月D日') + ' - ' + end.format('M月D日')
  }
  return currentDate.value.format('YYYY年M月')
})

const calendarDays = computed(() => Array.from({ length: 42 }, (_, index) => {
  const date = gridStart.value.add(index, 'day')
  return {
    key: date.format('YYYY-MM-DD'),
    date,
    isCurrentMonth: date.month() === currentDate.value.month(),
    isToday: date.isSame(dayjs(), 'day'),
  }
}))

const schedulesForDay = (date: Dayjs) =>
  schedules.value.filter(
    (schedule) =>
      (!categoryFilter.value || schedule.category === categoryFilter.value) &&
      dayjs(schedule.startTime).isSame(date, 'day'),
  )

const daySchedules = computed(() => schedulesForDay(currentDate.value))

const weekDays = computed(() => Array.from({ length: 7 }, (_, index) => startOfWeek(currentDate.value).add(index, 'day')))

const timeText = (value: string) => dayjs(value).format('HH:mm')
const dateValue = (date: Dayjs) => date.format('YYYY-MM-DD')

const loadSchedules = async () => {
  loading.value = true
  try {
    schedules.value = await listSchedules({
      start: range.value.start.toISOString(),
      end: range.value.end.toISOString(),
    })
  } finally {
    loading.value = false
  }
}

const navigate = async (step: number) => {
  const unit = viewMode.value === 'month' ? 'month' : viewMode.value === 'week' ? 'week' : 'day'
  currentDate.value = currentDate.value.add(step, unit)
  expandedDays.value = []
  await loadSchedules()
}

const goToday = async () => {
  currentDate.value = dayjs()
  expandedDays.value = []
  await loadSchedules()
}

const clearCategoryFilter = async () => {
  categoryFilter.value = ''
  await router.replace({ query: {} })
}

const switchView = async (mode: ViewMode) => {
  viewMode.value = mode
  expandedDays.value = []
  await loadSchedules()
}

const openCreate = (date?: Dayjs) => {
  editingSchedule.value = null
  defaultDate.value = dateValue(date ?? currentDate.value)
  dialogVisible.value = true
}

const openEdit = (schedule: Schedule) => {
  editingSchedule.value = schedule
  defaultDate.value = dateValue(dayjs(schedule.startTime))
  dialogVisible.value = true
}

const saveSchedule = async (payload: ScheduleFormPayload) => {
  saving.value = true
  try {
    if (editingSchedule.value) await updateSchedule(editingSchedule.value.id, payload)
    else await createSchedule(payload)
    ElMessage.success(editingSchedule.value ? '日程已更新' : '日程已创建')
    dialogVisible.value = false
    await loadSchedules()
  } finally {
    saving.value = false
  }
}

const removeSchedule = async (schedule: Schedule) => {
  await ElMessageBox.confirm('确定删除这条日程吗？', '删除日程', { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' })
  await deleteSchedule(schedule.id)
  ElMessage.success('日程已删除')
  await loadSchedules()
}

const toggleExpanded = (key: string) => {
  expandedDays.value = expandedDays.value.includes(key)
    ? expandedDays.value.filter((item) => item !== key)
    : [...expandedDays.value, key]
}

const priorityLabel = (priority: Schedule['priority']) => ({ high: '高', medium: '中', low: '低' })[priority]
const visibleSchedules = (date: Dayjs) => {
  const list = schedulesForDay(date)
  return expandedDays.value.includes(dateValue(date)) ? list : list.slice(0, 3)
}

const weekCellSchedules = (day: Dayjs, hour: number) =>
  schedulesForDay(day).filter((schedule) => dayjs(schedule.startTime).hour() === hour)

onMounted(loadSchedules)
</script>

<template>
  <section class="schedule-page">
    <header class="page-toolbar">
      <div><p>CALENDAR PLANNER</p><h2>日程统筹</h2></div>
      <el-button type="primary" @click="openCreate()"><el-icon><Plus /></el-icon>新建日程</el-button>
    </header>

    <section class="calendar-controls">
      <div class="view-switcher">
        <button :class="{ active: viewMode === 'day' }" @click="switchView('day')">日</button>
        <button :class="{ active: viewMode === 'week' }" @click="switchView('week')">周</button>
        <button :class="{ active: viewMode === 'month' }" @click="switchView('month')">月</button>
      </div>
      <div class="period-nav">
        <el-button circle @click="navigate(-1)"><el-icon><ArrowLeft /></el-icon></el-button>
        <strong>{{ navigationLabel }}</strong>
        <el-button circle @click="navigate(1)"><el-icon><ArrowRight /></el-icon></el-button>
        <el-button @click="goToday">今天</el-button>
        <el-tag v-if="categoryFilter" closable effect="light" @close="clearCategoryFilter">
          分类：{{ categoryFilter }}
        </el-tag>
      </div>
    </section>

    <section v-if="viewMode === 'month'" v-loading="loading" class="month-calendar">
      <div v-for="label in weekLabels" :key="label" class="week-head">{{ label }}</div>
      <div
        v-for="day in calendarDays"
        :key="day.key"
        class="calendar-cell"
        :class="{ muted: !day.isCurrentMonth, today: day.isToday }"
        @click="openCreate(day.date)"
      >
        <div class="cell-head"><span>{{ day.date.date() }}</span><small v-if="day.isToday">今天</small></div>
        <div class="cell-schedules">
          <button
            v-for="schedule in visibleSchedules(day.date)"
            :key="schedule.id"
            class="schedule-chip"
            :class="schedule.priority"
            @click.stop="openEdit(schedule)"
          >
            <span>{{ timeText(schedule.startTime) }}</span>
            <strong>{{ schedule.title }}</strong>
            <el-icon v-if="schedule.isRemind" class="chip-bell"><Bell /></el-icon>
          </button>
          <button
            v-if="schedulesForDay(day.date).length > 3"
            class="more-button"
            @click.stop="toggleExpanded(day.key)"
          >
            {{ expandedDays.includes(day.key) ? '收起' : '+' + (schedulesForDay(day.date).length - 3) + ' 更多' }}
          </button>
        </div>
      </div>
    </section>

    <section v-else-if="viewMode === 'week'" v-loading="loading" class="week-calendar">
      <div class="week-corner">时间</div>
      <div v-for="day in weekDays" :key="dateValue(day)" class="week-day-head" :class="{ today: day.isSame(dayjs(), 'day') }">
        <span>周{{ weekLabels[(day.day() + 6) % 7] }}</span><strong>{{ day.format('M/D') }}</strong>
      </div>
      <template v-for="hour in hours" :key="hour">
        <div class="hour-label">{{ String(hour).padStart(2, '0') }}:00</div>
        <div v-for="day in weekDays" :key="dateValue(day) + '-' + hour" class="week-cell" @dblclick="openCreate(day)">
          <button v-for="schedule in weekCellSchedules(day, hour)" :key="schedule.id" class="week-event" :class="schedule.priority" @click="openEdit(schedule)">
            <span>{{ timeText(schedule.startTime) }}</span>{{ schedule.title }}
          </button>
        </div>
      </template>
    </section>

    <section v-else v-loading="loading" class="day-calendar">
      <template v-for="hour in hours" :key="hour">
        <div class="day-hour">{{ String(hour).padStart(2, '0') }}:00</div>
        <div class="day-slot" @dblclick="openCreate(currentDate)">
          <button v-for="schedule in weekCellSchedules(currentDate, hour)" :key="schedule.id" class="day-event" :class="schedule.priority" @click="openEdit(schedule)">
            <div><strong>{{ schedule.title }}</strong><span>{{ timeText(schedule.startTime) }} · {{ schedule.category }}</span></div>
            <el-icon v-if="schedule.isRemind"><Bell /></el-icon>
          </button>
        </div>
      </template>
      <el-empty v-if="!loading && !daySchedules.length" description="今天没有日程安排" />
    </section>

    <ScheduleFormDialog
      v-model="dialogVisible"
      :record="editingSchedule"
      :default-date="defaultDate"
      :saving="saving"
      @save="saveSchedule"
    />
  </section>
</template>

<style scoped lang="scss">
.schedule-page { display: grid; gap: 18px; animation: schedule-in 0.35s ease both; }
@keyframes schedule-in { from { opacity: 0; transform: translateY(7px); } }
.page-toolbar { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
.page-toolbar p { margin: 0 0 6px; color: var(--primary); font-size: 12px; font-weight: 800; letter-spacing: 0.18em; }
.page-toolbar h2 { margin: 0; color: var(--text-primary); font-size: 28px; letter-spacing: -0.04em; }
.calendar-controls { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.view-switcher { display: flex; padding: 3px; border: 1px solid var(--border-soft); border-radius: 11px; background: var(--surface-muted); }
.view-switcher button { width: 54px; height: 34px; border: 0; border-radius: 8px; color: var(--text-regular); background: transparent; cursor: pointer; }
.view-switcher button.active { color: #fff; background: var(--primary); box-shadow: 0 5px 14px color-mix(in srgb, var(--primary) 25%, transparent); }
.period-nav { display: flex; align-items: center; gap: 8px; }
.period-nav strong { min-width: 175px; color: var(--text-primary); font-size: 15px; text-align: center; }
.month-calendar { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); overflow: hidden; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-sm); }
.week-head { padding: 11px 8px; border-bottom: 1px solid var(--border-soft); color: var(--text-secondary); background: var(--surface-muted); font-size: 12px; font-weight: 700; text-align: center; }
.calendar-cell { min-height: 128px; padding: 8px; border-right: 1px solid var(--border-soft); border-bottom: 1px solid var(--border-soft); cursor: pointer; transition: background 0.18s ease; }
.calendar-cell:nth-child(7n + 7) { border-right: 0; }
.calendar-cell:hover { background: color-mix(in srgb, var(--primary-soft) 35%, var(--surface)); }
.calendar-cell.muted { background: color-mix(in srgb, var(--surface-muted) 65%, transparent); }
.calendar-cell.muted .cell-head > span { color: var(--text-secondary); opacity: 0.6; }
.calendar-cell.today { border: 1.5px solid var(--primary); background: color-mix(in srgb, var(--primary-soft) 65%, var(--surface)); box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--primary) 10%, transparent); }
.cell-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }
.cell-head > span { display: grid; width: 25px; height: 25px; place-items: center; border-radius: 8px; color: var(--text-primary); font-size: 13px; font-weight: 700; }
.today .cell-head > span { color: #fff; background: var(--primary); }
.cell-head small { color: var(--primary); font-size: 12px; }
.cell-schedules { display: grid; gap: 4px; }
.schedule-chip { position: relative; display: grid; width: 100%; grid-template-columns: auto 1fr auto; align-items: center; gap: 5px; padding: 5px 6px; border: 0; border-left: 3px solid var(--primary); border-radius: 6px; color: var(--text-primary); background: var(--primary-soft); text-align: left; cursor: pointer; }
.schedule-chip.high { border-left-color: var(--danger); background: color-mix(in srgb, var(--danger) 11%, var(--surface)); }
.schedule-chip.medium { border-left-color: var(--primary); }
.schedule-chip.low { border-left-color: var(--secondary); background: color-mix(in srgb, var(--secondary-soft) 70%, var(--surface)); }
.schedule-chip span { color: var(--text-secondary); font-size: 12px; }
.schedule-chip strong { overflow: hidden; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.chip-bell { color: var(--warning); font-size: 12px; }
.more-button { padding: 3px 6px; border: 0; color: var(--primary); background: transparent; font-size: 12px; text-align: left; cursor: pointer; }
.week-calendar { display: grid; grid-template-columns: 64px repeat(7, minmax(0, 1fr)); max-height: 68vh; overflow: auto; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); }
.week-corner, .week-day-head { position: sticky; top: 0; z-index: 2; padding: 10px 6px; border-bottom: 1px solid var(--border-soft); background: var(--surface-muted); text-align: center; }
.week-corner { left: 0; z-index: 3; color: var(--text-secondary); font-size: 12px; }
.week-day-head span, .week-day-head strong { display: block; }
.week-day-head span { color: var(--text-secondary); font-size: 12px; }
.week-day-head strong { margin-top: 3px; color: var(--text-primary); font-size: 13px; }
.week-day-head.today strong { color: var(--primary); }
.hour-label { position: sticky; left: 0; z-index: 1; padding: 9px 7px; border-right: 1px solid var(--border-soft); border-bottom: 1px solid var(--border-soft); color: var(--text-secondary); background: var(--surface-muted); font-size: 12px; text-align: right; }
.week-cell { min-height: 48px; padding: 3px; border-right: 1px solid var(--border-soft); border-bottom: 1px solid var(--border-soft); }
.week-event { display: block; width: 100%; padding: 4px 5px; margin-bottom: 2px; overflow: hidden; border: 0; border-radius: 5px; color: var(--text-primary); background: var(--primary-soft); font-size: 12px; text-align: left; text-overflow: ellipsis; white-space: nowrap; cursor: pointer; }
.week-event.high, .day-event.high { border-left: 3px solid var(--danger); }
.week-event.medium, .day-event.medium { border-left: 3px solid var(--primary); }
.week-event.low, .day-event.low { border-left: 3px solid var(--secondary); }
.week-event span { display: block; color: var(--text-secondary); font-size: 12px; }
.day-calendar { display: grid; grid-template-columns: 72px 1fr; max-height: 68vh; overflow: auto; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); }
.day-hour { padding: 12px 9px; border-right: 1px solid var(--border-soft); border-bottom: 1px solid var(--border-soft); color: var(--text-secondary); background: var(--surface-muted); font-size: 12px; text-align: right; }
.day-slot { position: relative; min-height: 58px; padding: 6px; border-bottom: 1px solid var(--border-soft); }
.day-event { display: flex; width: 100%; align-items: center; justify-content: space-between; padding: 9px 11px; border: 0; border-radius: 9px; color: var(--text-primary); background: var(--primary-soft); cursor: pointer; }
.day-event strong, .day-event span { display: block; text-align: left; }
.day-event strong { font-size: 13px; }
.day-event span { margin-top: 3px; color: var(--text-secondary); font-size: 12px; }
@media (max-width: 860px) {
  .calendar-controls, .page-toolbar { align-items: flex-start; flex-direction: column; }
  .month-calendar { overflow-x: auto; grid-template-columns: repeat(7, minmax(105px, 1fr)); }
  .calendar-cell { min-height: 112px; }
  .week-calendar { min-width: 780px; }
}
</style>

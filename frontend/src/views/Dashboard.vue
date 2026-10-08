<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import dayjs from 'dayjs'
import 'dayjs/locale/zh-cn'
import { Refresh, Sunny } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getDashboardSummary } from '@/api/dashboard'
import { checkInHabit } from '@/api/habits'
import { listSchedules } from '@/api/schedule'
import { useUserStore } from '@/stores/user'
import ScheduleCard from '@/components/dashboard/ScheduleCard.vue'
import HabitCard from '@/components/dashboard/HabitCard.vue'
import LearningCard from '@/components/dashboard/LearningCard.vue'
import InterviewCard from '@/components/dashboard/InterviewCard.vue'
import FinanceCard from '@/components/dashboard/FinanceCard.vue'
import HealthCard from '@/components/dashboard/HealthCard.vue'
import ShoppingCard from '@/components/dashboard/ShoppingCard.vue'
import QuickActionsCard from '@/components/dashboard/QuickActionsCard.vue'
import type { DashboardSummary, Habit, Schedule } from '@/types'

dayjs.locale('zh-cn')

const userStore = useUserStore()
const loading = ref(true)

const createEmptySummary = (): DashboardSummary => ({
  date: dayjs().format('YYYY-MM-DD'),
  schedules: [],
  habits: [],
  learning: { todayDuration: 0, tasks: [] },
  interviews: [],
  finance: { income: 0, expense: 0, balance: 0 },
  health: { latestWeight: null, sevenDayAverage: null, records: [] },
  shopping: [],
})

const summary = ref<DashboardSummary>(createEmptySummary())
/** 面试安排面板读的是日程里「面试」分类的近期条目，与 /schedule 页面同源 */
const interviewSchedules = ref<Schedule[]>([])

const today = dayjs()
const dateLabel = computed(() => today.format('M月D日·dddd'))
const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 6) return '夜深了，超级管理员'
  if (hour < 12) return '早上好，超级管理员'
  if (hour < 14) return '中午好，超级管理员'
  if (hour < 18) return '下午好，超级管理员'
  return '晚上好，超级管理员'
})

const completedHabits = computed(() => summary.value.habits.filter((item) => item.checkedToday).length)
const completionRate = computed(() =>
  summary.value.habits.length ? Math.round((completedHabits.value / summary.value.habits.length) * 100) : 0,
)

const loadSummary = async () => {
  loading.value = true
  try {
    const [data, upcoming] = await Promise.all([
      getDashboardSummary(),
      listSchedules({ start: dayjs().toISOString(), end: dayjs().add(180, 'day').toISOString() }),
    ])
    summary.value = data
    interviewSchedules.value = upcoming.filter((item) => item.category === '面试')
  } finally {
    loading.value = false
  }
}

const onCheckIn = async (habit: Habit) => {
  if (habit.checkedToday) {
    ElMessage.info(`${habit.name} 今天已经打卡`)
    return
  }
  await checkInHabit(habit.id)
  habit.checkedToday = true
  habit.streakDays += 1
  ElMessage.success(`已完成「${habit.name}」打卡`)
}

onMounted(async () => {
  await Promise.allSettled([loadSummary(), userStore.fetchProfile()])
})
</script>

<template>
  <section class="dashboard-page">
    <div class="welcome-panel">
      <div class="welcome-copy">
        <div class="date-pill">
          <el-icon><Sunny /></el-icon>
          {{ dateLabel }}
        </div>
        <h2>{{ greeting }}</h2>
        <p>回顾今天，收获一点进步。</p>
      </div>

      <div class="daily-progress">
        <div class="progress-ring" :style="{ '--progress': `${completionRate * 3.6}deg` }">
          <div>
            <strong>{{ completionRate }}%</strong>
            <span>今日完成</span>
          </div>
        </div>
        <div class="progress-copy">
          <span>习惯进度</span>
          <strong>{{ completedHabits }}/{{ summary.habits.length || 0 }}</strong>
          <small>每一项坚持都算数</small>
        </div>
      </div>

      <el-button class="refresh-button" circle :loading="loading" aria-label="刷新数据" @click="loadSummary">
        <el-icon v-if="!loading"><Refresh /></el-icon>
      </el-button>
    </div>

    <div class="dashboard-grid">
      <ScheduleCard :schedules="summary.schedules" :loading="loading" />
      <HabitCard :habits="summary.habits" :loading="loading" @check-in="onCheckIn" />
      <LearningCard
        :tasks="summary.learning.tasks"
        :today-duration="summary.learning.todayDuration"
        :loading="loading"
      />
      <InterviewCard :schedules="interviewSchedules" :loading="loading" />
      <FinanceCard
        :income="summary.finance.income"
        :expense="summary.finance.expense"
        :balance="summary.finance.balance"
        :loading="loading"
      />
      <HealthCard
        :latest-weight="summary.health.latestWeight"
        :seven-day-average="summary.health.sevenDayAverage"
        :records="summary.health.records"
        :loading="loading"
      />
      <ShoppingCard :items="summary.shopping" :loading="loading" />
      <QuickActionsCard />
    </div>
  </section>
</template>

<style scoped lang="scss">
.dashboard-page {
  animation: dashboard-in 0.45s ease both;
}

@keyframes dashboard-in {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
}

.welcome-panel {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 25px;
  min-height: 150px;
  padding: 26px 30px;
  margin-bottom: 22px;
  overflow: hidden;
  border: 1px solid color-mix(in srgb, var(--primary) 17%, var(--border-color));
  border-radius: var(--radius-lg);
  background:
    radial-gradient(circle at 82% 20%, color-mix(in srgb, var(--primary) 18%, transparent), transparent 14rem),
    radial-gradient(circle at 64% 100%, color-mix(in srgb, var(--secondary) 12%, transparent), transparent 12rem),
    linear-gradient(135deg, var(--surface-raised), color-mix(in srgb, var(--primary-soft) 32%, var(--surface)));
  box-shadow: var(--shadow-sm);
}

.welcome-panel::after {
  position: absolute;
  top: -80px;
  right: 180px;
  width: 160px;
  height: 160px;
  border: 1px solid color-mix(in srgb, var(--primary) 12%, transparent);
  border-radius: 50%;
  content: '';
}

.welcome-copy {
  position: relative;
  z-index: 1;
}

.date-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 9px;
  margin-bottom: 11px;
  border: 1px solid color-mix(in srgb, var(--warning) 18%, var(--border-color));
  border-radius: 99px;
  color: color-mix(in srgb, var(--warning) 86%, var(--text-primary));
  background: color-mix(in srgb, var(--warning) 10%, transparent);
  font-size: 12px;
  font-weight: 700;
}

.welcome-copy h2 {
  margin: 0;
  color: var(--text-primary);
  font-size: clamp(23px, 2.4vw, 32px);
  line-height: 1.2;
  letter-spacing: -0.04em;
}

.welcome-copy p {
  margin: 8px 0 0;
  color: var(--text-secondary);
  font-size: 13px;
}

.daily-progress {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 13px;
}

.progress-ring {
  display: grid;
  width: 86px;
  height: 86px;
  flex: none;
  place-items: center;
  border-radius: 50%;
  background: conic-gradient(var(--primary) var(--progress), var(--border-soft) 0deg);
}

.progress-ring::before {
  position: absolute;
  width: 68px;
  height: 68px;
  border-radius: 50%;
  background: color-mix(in srgb, var(--surface) 94%, transparent);
  content: '';
}

.progress-ring > div {
  position: relative;
  z-index: 1;
  text-align: center;
}

.progress-ring strong,
.progress-ring span {
  display: block;
}

.progress-ring strong {
  color: var(--text-primary);
  font-size: 18px;
}

.progress-ring span {
  color: var(--text-secondary);
  font-size: 12px;
}

.progress-copy span,
.progress-copy strong,
.progress-copy small {
  display: block;
}

.progress-copy span {
  color: var(--text-secondary);
  font-size: 12px;
}

.progress-copy strong {
  margin: 3px 0;
  color: var(--text-primary);
  font-size: 23px;
}

.progress-copy small {
  color: var(--text-secondary);
  font-size: 12px;
}

.refresh-button {
  position: absolute;
  top: 18px;
  right: 18px;
  z-index: 2;
  color: var(--text-secondary);
  background: color-mix(in srgb, var(--surface) 72%, transparent);
  backdrop-filter: blur(8px);
}

.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 20px;
}

@media (max-width: 1280px) {
  .dashboard-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 760px) {
  .welcome-panel {
    min-height: 176px;
    align-items: flex-start;
    padding: 24px 20px;
  }

  .daily-progress {
    position: absolute;
    right: 17px;
    bottom: 16px;
  }

  .progress-ring {
    width: 68px;
    height: 68px;
  }

  .progress-ring::before {
    width: 54px;
    height: 54px;
  }

  .progress-copy {
    display: none;
  }

  .dashboard-grid {
    grid-template-columns: 1fr;
    gap: 15px;
  }
}
</style>
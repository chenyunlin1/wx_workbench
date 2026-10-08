<script setup lang="ts">
import { ArrowRight, Check, Medal } from '@element-plus/icons-vue'
import type { Habit } from '@/types'

defineProps<{
  habits: Habit[]
  loading?: boolean
}>()

const emit = defineEmits<{
  checkIn: [habit: Habit]
}>()
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card habit-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon green"><el-icon><Medal /></el-icon></span>
          <div>
            <h3>习惯打卡</h3>
            <p>今天也要认真坚持</p>
          </div>
        </div>
        <router-link class="text-link" to="/habits">习惯健康 <el-icon><ArrowRight /></el-icon></router-link>
      </div>
    </template>

    <div v-if="habits.length" class="habit-list">
      <button
        v-for="habit in habits.slice(0, 3)"
        :key="habit.id"
        class="habit-item"
        @click="emit('checkIn', habit)"
      >
        <span class="habit-icon">{{ habit.icon || '✨' }}</span>
        <span class="habit-copy">
          <strong>{{ habit.name }}</strong>
          <small>连续 {{ habit.streakDays }} 天</small>
        </span>
        <span class="check-button" :class="{ checked: habit.checkedToday }">
          <el-icon><Check /></el-icon>
        </span>
      </button>
    </div>

    <div v-else class="empty-state">
      <div class="habit-orbits">
        <span>✓</span>
      </div>
      <strong>还没有习惯，去添加一个吧</strong>
      <p>从每天 5 分钟的小目标开始</p>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.habit-card {
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

.habit-list {
  display: grid;
  gap: 9px;
}

.habit-item {
  display: flex;
  align-items: center;
  width: 100%;
  gap: 11px;
  padding: 10px 11px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  color: inherit;
  background: var(--surface-muted);
  cursor: pointer;
  transition: all 0.2s ease;
}

.habit-item:hover {
  border-color: color-mix(in srgb, var(--secondary) 35%, var(--border-color));
  background: color-mix(in srgb, var(--secondary-soft) 45%, var(--surface));
  transform: translateX(2px);
}

.habit-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: none;
  place-items: center;
  border-radius: 11px;
  background: var(--surface);
  box-shadow: var(--shadow-xs);
}

.habit-copy {
  min-width: 0;
  flex: 1;
  text-align: left;
}

.habit-copy strong,
.habit-copy small {
  display: block;
}

.habit-copy strong {
  color: var(--text-primary);
  font-size: 13px;
}

.habit-copy small {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.check-button {
  display: grid;
  width: 26px;
  height: 26px;
  place-items: center;
  border: 1px solid var(--border-color);
  border-radius: 50%;
  color: transparent;
  background: var(--surface);
}

.check-button.checked {
  border-color: var(--secondary);
  color: #fff;
  background: var(--secondary);
  box-shadow: 0 0 0 4px var(--secondary-soft);
}

.empty-state {
  padding-top: 25px;
  text-align: center;
}

.habit-orbits {
  position: relative;
  display: grid;
  width: 62px;
  height: 62px;
  margin: 0 auto 13px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: var(--secondary);
  box-shadow: 0 12px 28px color-mix(in srgb, var(--secondary) 28%, transparent);
  font-size: 28px;
}

.habit-orbits::before,
.habit-orbits::after {
  position: absolute;
  border: 1px solid color-mix(in srgb, var(--secondary) 30%, transparent);
  border-radius: 50%;
  content: '';
}

.habit-orbits::before {
  inset: -7px;
}

.habit-orbits::after {
  inset: -13px;
  border-style: dashed;
  transform: rotate(25deg);
}

.empty-state strong {
  display: block;
  font-size: 14px;
}

.empty-state p {
  margin: 5px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}
</style>
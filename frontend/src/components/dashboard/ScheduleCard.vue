<script setup lang="ts">
import { ArrowRight, Calendar } from '@element-plus/icons-vue'
import dayjs from 'dayjs'
import type { Schedule } from '@/types'

defineProps<{
  schedules: Schedule[]
  loading?: boolean
}>()
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card schedule-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon blue"><el-icon><Calendar /></el-icon></span>
          <div>
            <h3>今日日程</h3>
            <p>{{ schedules.length ? `${schedules.length} 项安排` : '留白也是计划' }}</p>
          </div>
        </div>
        <router-link class="text-link" to="/schedule">日程统筹 <el-icon><ArrowRight /></el-icon></router-link>
      </div>
    </template>

    <div v-if="schedules.length" class="schedule-list">
      <article v-for="item in schedules.slice(0, 3)" :key="item.id" class="schedule-item">
        <div class="time-rail">
          <strong>{{ dayjs(item.startTime).format('HH:mm') }}</strong>
          <span>{{ dayjs(item.endTime).format('HH:mm') }}</span>
        </div>
        <div class="schedule-copy">
          <strong>{{ item.title }}</strong>
          <span>{{ item.description || '按计划专注完成' }}</span>
        </div>
        <i />
      </article>
    </div>

    <div v-else class="empty-state schedule-empty">
      <div class="empty-visual">
        <el-icon><Calendar /></el-icon>
        <span class="orbit" />
      </div>
      <strong>今天没有日程安排</strong>
      <p>给自己留一点自由呼吸的时间</p>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.schedule-card {
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

.heading-icon.blue {
  color: var(--primary);
  background: var(--primary-soft);
}

h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 16px;
  line-height: 1.25;
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
  transition: color 0.2s;
}

.text-link:hover {
  color: var(--primary);
}

.schedule-list {
  display: grid;
  gap: 8px;
}

.schedule-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 11px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
}

.time-rail {
  display: grid;
  width: 44px;
  gap: 2px;
  padding-right: 10px;
  border-right: 1px solid var(--border-color);
}

.time-rail strong {
  color: var(--primary);
  font-size: 13px;
}

.time-rail span,
.schedule-copy span {
  color: var(--text-secondary);
  font-size: 12px;
}

.schedule-copy {
  min-width: 0;
  flex: 1;
}

.schedule-copy strong,
.schedule-copy span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.schedule-copy strong {
  margin-bottom: 3px;
  color: var(--text-primary);
  font-size: 13px;
}

.schedule-item > i {
  width: 7px;
  height: 7px;
  flex: none;
  border: 2px solid color-mix(in srgb, var(--primary) 35%, transparent);
  border-radius: 50%;
  background: var(--primary);
}

.schedule-empty {
  padding-top: 30px;
}

.empty-state {
  text-align: center;
}

.empty-visual {
  position: relative;
  display: grid;
  width: 64px;
  height: 64px;
  margin: 0 auto 13px;
  place-items: center;
  border: 1px dashed color-mix(in srgb, var(--primary) 35%, var(--border-color));
  border-radius: 20px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 26px;
}

.orbit {
  position: absolute;
  inset: -6px;
  border: 1px solid color-mix(in srgb, var(--secondary) 25%, transparent);
  border-radius: 24px;
  transform: rotate(9deg);
}

.empty-state strong {
  display: block;
  color: var(--text-primary);
  font-size: 14px;
}

.empty-state p {
  margin: 5px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}
</style>
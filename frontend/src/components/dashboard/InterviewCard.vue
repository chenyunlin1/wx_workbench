<script setup lang="ts">
import { ArrowRight, Briefcase } from '@element-plus/icons-vue'
import dayjs from 'dayjs'
import type { Schedule } from '@/types'

defineProps<{
  schedules: Schedule[]
  loading?: boolean
}>()

const priorityLabel: Record<Schedule['priority'], string> = {
  high: '高优先',
  medium: '中优先',
  low: '低优先',
}
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card interview-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon amber"><el-icon><Briefcase /></el-icon></span>
          <div>
            <h3>面试安排</h3>
            <p>日程里的「面试」分类</p>
          </div>
        </div>
        <router-link class="text-link" :to="{ path: '/schedule', query: { category: '面试' } }">
          日程 <el-icon><ArrowRight /></el-icon>
        </router-link>
      </div>
    </template>

    <div v-if="schedules.length" class="interview-list">
      <article v-for="item in schedules.slice(0, 2)" :key="item.id" class="interview-item">
        <div class="company-logo">{{ item.title.slice(0, 1) }}</div>
        <div class="interview-copy">
          <strong>{{ item.title }}</strong>
          <span>{{ dayjs(item.startTime).format('M月D日 HH:mm') }}</span>
        </div>
        <div class="interview-meta">
          <i :class="item.priority">{{ priorityLabel[item.priority] }}</i>
        </div>
      </article>
    </div>

    <div v-else class="empty-interview">
      <div class="briefcase-visual">
        <el-icon><Briefcase /></el-icon>
      </div>
      <strong>暂无面试安排</strong>
      <p>在日程里新建一条，分类选「面试」即可</p>
      <span class="line-decoration"><i /><i /><i /><i /><i /></span>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.interview-card {
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

.heading-icon.amber {
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, transparent);
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

.interview-list {
  display: grid;
  gap: 10px;
  padding-top: 7px;
}

.interview-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px;
  border: 1px solid var(--border-soft);
  border-radius: 13px;
  background: var(--surface-muted);
}

.company-logo {
  display: grid;
  width: 38px;
  height: 38px;
  flex: none;
  place-items: center;
  border-radius: 12px;
  color: #fff;
  background: var(--warning);
  font-size: 17px;
  font-weight: 800;
}

.interview-copy {
  min-width: 0;
  flex: 1;
}

.interview-copy strong,
.interview-copy span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.interview-copy strong {
  font-size: 13px;
}

.interview-copy span {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.interview-meta {
  text-align: right;
}

.interview-meta i {
  display: inline-block;
  padding: 2px 6px;
  border-radius: 99px;
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 12%, transparent);
  font-size: 12px;
  font-style: normal;
}

.interview-meta i.high {
  color: var(--danger);
  background: color-mix(in srgb, var(--danger) 12%, transparent);
}

.interview-meta i.low {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.empty-interview {
  padding-top: 23px;
  text-align: center;
}

.briefcase-visual {
  display: grid;
  width: 58px;
  height: 58px;
  margin: 0 auto 12px;
  place-items: center;
  border-radius: 18px;
  color: var(--warning);
  background: linear-gradient(145deg, color-mix(in srgb, var(--warning) 18%, var(--surface)), var(--surface));
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--warning) 22%, transparent);
  font-size: 25px;
  transform: rotate(-3deg);
}

.empty-interview strong {
  display: block;
  font-size: 14px;
}

.empty-interview p {
  margin: 5px 0 13px;
  color: var(--text-secondary);
  font-size: 12px;
}

.line-decoration {
  display: flex;
  justify-content: center;
  gap: 4px;
}

.line-decoration i {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: color-mix(in srgb, var(--warning) 45%, var(--border-color));
}

.line-decoration i:nth-child(3) {
  width: 18px;
  border-radius: 99px;
}
</style>

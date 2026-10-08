<script setup lang="ts">
import { computed } from 'vue'
import { ArrowRight, Clock, Reading } from '@element-plus/icons-vue'
import type { LearningTask } from '@/types'

const props = defineProps<{
  tasks: LearningTask[]
  todayDuration: number
  loading?: boolean
}>()

const doneCount = computed(() => props.tasks.filter((task) => task.status === 'done').length)
const doingCount = computed(() => props.tasks.filter((task) => task.status === 'doing').length)
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card learning-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon violet"><el-icon><Reading /></el-icon></span>
          <div>
            <h3>学习任务</h3>
            <p>保持输入，持续成长</p>
          </div>
        </div>
        <router-link class="text-link" to="/learning">学习知识库 <el-icon><ArrowRight /></el-icon></router-link>
      </div>
    </template>

    <div class="duration-panel">
      <div class="duration-icon"><el-icon><Clock /></el-icon></div>
      <div>
        <span>今日学习时长</span>
        <strong>{{ todayDuration }}<small>分钟</small></strong>
      </div>
      <div class="duration-stats">
        <span class="stat-pill done">已完成 {{ doneCount }}</span>
        <span class="stat-pill doing">进行中 {{ doingCount }}</span>
      </div>
    </div>

    <div v-if="tasks.length" class="task-list">
      <div v-for="task in tasks.slice(0, 2)" :key="task.id" class="task-item">
        <span class="task-dot" :class="task.status" />
        <div>
          <strong>{{ task.title }}</strong>
          <small>{{ task.duration }} 分钟 · {{ task.status === 'done' ? '已完成' : '待学习' }}</small>
        </div>
        <span class="task-status">{{ task.status === 'done' ? 'DONE' : 'TODO' }}</span>
      </div>
    </div>

    <div v-else class="empty-learning">
      <span>今天还没有学习任务</span>
      <router-link to="/learning">去添加</router-link>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.learning-card {
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

.heading-icon.violet {
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 14%, transparent);
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

.duration-panel {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 76px;
  padding: 12px 14px;
  margin-bottom: 12px;
  border: 1px solid color-mix(in srgb, var(--accent) 18%, var(--border-color));
  border-radius: 14px;
  background: linear-gradient(120deg, color-mix(in srgb, var(--accent) 10%, var(--surface)), var(--surface));
}

.duration-icon {
  display: grid;
  width: 38px;
  height: 38px;
  flex: none;
  place-items: center;
  border-radius: 12px;
  color: #fff;
  background: var(--accent);
  font-size: 20px;
}

.duration-panel > div:nth-child(2) {
  min-width: 92px;
}

.duration-panel span {
  display: block;
  color: var(--text-secondary);
  font-size: 12px;
}

.duration-panel strong {
  color: var(--text-primary);
  font-size: 25px;
  line-height: 1.15;
}

.duration-panel strong small {
  margin-left: 4px;
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: 500;
}

.duration-stats {
  display: flex;
  flex: 1;
  flex-wrap: wrap;
  gap: 6px;
  justify-content: flex-end;
}

.stat-pill {
  padding: 3px 10px;
  border-radius: 99px;
  font-size: 12px;
}

.stat-pill.done {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.stat-pill.doing {
  color: var(--primary);
  background: var(--primary-soft);
}

.task-list {
  display: grid;
  gap: 8px;
}

.task-item {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 10px;
  border-radius: 10px;
  background: var(--surface-muted);
}

.task-dot {
  width: 8px;
  height: 8px;
  flex: none;
  border-radius: 3px;
  background: var(--warning);
}

.task-dot.done {
  background: var(--secondary);
}

.task-item > div {
  min-width: 0;
  flex: 1;
}

.task-item strong,
.task-item small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.task-item strong {
  color: var(--text-primary);
  font-size: 13px;
}

.task-item small {
  margin-top: 2px;
  color: var(--text-secondary);
  font-size: 12px;
}

.task-status {
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.empty-learning {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px;
  border: 1px dashed var(--border-color);
  border-radius: 12px;
  color: var(--text-secondary);
  font-size: 13px;
}

.empty-learning a {
  color: var(--primary);
  font-weight: 700;
}
</style>
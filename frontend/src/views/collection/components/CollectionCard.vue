<script setup lang="ts">
import { computed } from 'vue'
import { Delete, Edit, Picture } from '@element-plus/icons-vue'
import { statusLabel, typeMeta } from '../collection-meta'
import type { CollectionItem } from '@/types'

const props = defineProps<{
  item: CollectionItem
}>()

const emit = defineEmits<{
  edit: []
  remove: []
  'cycle-status': []
}>()

const meta = computed(() => typeMeta(props.item.type))
const statusText = computed(() => statusLabel(props.item.status, props.item.type))
const initial = computed(() => props.item.title.trim().slice(0, 2))
</script>

<template>
  <article class="cover-card" :class="meta.tone">
    <div class="cover">
      <el-image v-if="item.coverUrl" :src="item.coverUrl" fit="cover" lazy class="cover-image">
        <template #error>
          <div class="cover-fallback">
            <el-icon><Picture /></el-icon>
            <span>{{ initial }}</span>
          </div>
        </template>
      </el-image>
      <div v-else class="cover-fallback">
        <el-icon><component :is="meta.icon" /></el-icon>
        <span>{{ initial }}</span>
      </div>

      <span class="type-badge">{{ meta.label }}</span>

      <div class="cover-actions">
        <el-button circle size="small" @click="emit('edit')">
          <el-icon><Edit /></el-icon>
        </el-button>
        <el-button circle size="small" type="danger" @click="emit('remove')">
          <el-icon><Delete /></el-icon>
        </el-button>
      </div>
    </div>

    <div class="cover-body">
      <strong class="cover-title" :title="item.title">{{ item.title }}</strong>

      <div class="cover-meta">
        <span v-if="item.year" class="year">{{ item.year }}</span>
        <el-rate
          v-if="item.rating"
          :model-value="item.rating"
          disabled
          size="small"
          class="cover-rate"
        />
        <span v-else class="no-rating">未评分</span>
      </div>

      <button type="button" class="status-pill" :class="`is-${item.status}`" @click="emit('cycle-status')">
        {{ statusText }}
      </button>

      <p v-if="item.comment" class="cover-comment">{{ item.comment }}</p>
    </div>
  </article>
</template>

<style scoped lang="scss">
.cover-card {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
}

.cover-card:hover {
  border-color: color-mix(in srgb, var(--primary) 30%, var(--border-color));
  box-shadow: var(--shadow-md);
  transform: translateY(-3px);
}

.cover {
  position: relative;
  aspect-ratio: 3 / 4;
  overflow: hidden;
  background: var(--surface-muted);
}

.cover-image {
  width: 100%;
  height: 100%;
}

.cover-fallback {
  display: grid;
  width: 100%;
  height: 100%;
  place-content: center;
  place-items: center;
  gap: 8px;
  color: #fff;
  font-size: 25px;
}

.cover-fallback span {
  font-size: 20px;
  font-weight: 800;
  letter-spacing: 0.06em;
  opacity: 0.92;
}

.cover-card.blue .cover-fallback {
  background: var(--primary);
}

.cover-card.violet .cover-fallback {
  background: var(--accent);
}

.cover-card.green .cover-fallback {
  background: var(--secondary);
}

.type-badge {
  position: absolute;
  top: 9px;
  left: 9px;
  padding: 2px 9px;
  border-radius: 99px;
  color: #fff;
  background: rgba(15, 23, 42, 0.55);
  backdrop-filter: blur(6px);
  font-size: 12px;
  letter-spacing: 0.06em;
}

.cover-actions {
  position: absolute;
  top: 7px;
  right: 7px;
  display: flex;
  gap: 6px;
  opacity: 0;
  transition: opacity 0.18s ease;
}

.cover-card:hover .cover-actions {
  opacity: 1;
}

.cover-body {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 7px;
  padding: 11px 12px 13px;
}

.cover-title {
  display: -webkit-box;
  overflow: hidden;
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.45;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.cover-meta {
  display: flex;
  gap: 8px;
  align-items: center;
  min-height: 16px;
}

.cover-meta .year {
  color: var(--text-secondary);
  font-size: 13px;
}

.cover-rate :deep(.el-rate__icon) {
  margin-right: 1px;
  font-size: 14px;
}

.no-rating {
  color: var(--text-secondary);
  font-size: 13px;
}

.status-pill {
  align-self: flex-start;
  padding: 2px 10px;
  border-radius: 99px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.status-pill.is-wish {
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, transparent);
}

.status-pill.is-doing {
  color: var(--primary);
  background: var(--primary-soft);
}

.status-pill.is-done {
  color: var(--secondary);
  background: color-mix(in srgb, var(--secondary) 14%, transparent);
}

.status-pill:hover {
  filter: brightness(0.96);
  transform: translateY(-1px);
}

.cover-comment {
  display: -webkit-box;
  overflow: hidden;
  margin: 0;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.6;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
</style>

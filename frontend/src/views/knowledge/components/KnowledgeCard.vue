<script setup lang="ts">
import dayjs from 'dayjs'
import { Check, CircleCheck, CircleClose, CollectionTag, QuestionFilled } from '@element-plus/icons-vue'
import type { KnowledgeItem } from '@/types'

const props = defineProps<{
  item: KnowledgeItem
  selected: boolean
}>()

const emit = defineEmits<{
  select: [id: number, checked: boolean]
  toggleLearned: [item: KnowledgeItem]
  open: [item: KnowledgeItem]
}>()

const formatDate = (date: string) => dayjs(date).format('YYYY/M/D')

const onSelect = (value: string | number | boolean) => {
  emit('select', props.item.id, Boolean(value))
}
</script>

<template>
  <article class="knowledge-item" :class="{ selected }">
    <div class="item-top">
      <el-checkbox
        :model-value="selected"
        class="item-checkbox"
        @change="onSelect"
      />
      <span class="type-badge" :class="item.type">
        <el-icon><CollectionTag v-if="item.type === 'note'" /><QuestionFilled v-else /></el-icon>
        {{ item.type === 'note' ? '✨ 笔记' : '❓ 问答' }}
      </span>
      <button class="learned-toggle" :class="{ learned: item.isLearned }" @click="emit('toggleLearned', item)">
        <el-icon><CircleCheck v-if="item.isLearned" /><CircleClose v-else /></el-icon>
        {{ item.isLearned ? '● 已学习' : '○ 标记已学习' }}
      </button>
      <span class="item-date">{{ formatDate(item.updatedAt) }}</span>
    </div>

    <button class="item-title" @click="emit('open', item)">{{ item.title }}</button>
    <p class="item-summary">{{ item.content }}</p>

    <div class="item-bottom">
      <div class="item-tags">
        <el-tag v-for="tag in item.tags" :key="tag" size="small" effect="light" round>
          {{ tag }}
        </el-tag>
      </div>
      <span v-if="item.views" class="item-views">{{ item.views }} 次点击</span>
      <el-icon v-if="item.isLearned" class="learned-mark"><Check /></el-icon>
    </div>
  </article>
</template>

<style scoped lang="scss">
.knowledge-item {
  padding: 18px 20px 16px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
  transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
}

.knowledge-item:hover,
.knowledge-item.selected {
  border-color: color-mix(in srgb, var(--primary) 34%, var(--border-color));
  box-shadow: var(--shadow-sm);
  transform: translateY(-2px);
}

.knowledge-item.selected {
  background: linear-gradient(90deg, color-mix(in srgb, var(--primary-soft) 58%, var(--surface)), var(--surface));
}

.item-top,
.item-bottom,
.item-tags,
.type-badge,
.learned-toggle {
  display: flex;
  align-items: center;
}

.item-top {
  gap: 11px;
}

.item-checkbox {
  margin-right: 1px;
}

.type-badge {
  gap: 4px;
  padding: 4px 8px;
  border-radius: 7px;
  font-size: 12px;
}

.type-badge.note {
  color: var(--primary);
  background: var(--primary-soft);
}

.type-badge.qa {
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 13%, transparent);
}

.learned-toggle {
  gap: 4px;
  padding: 4px 7px;
  border: 0;
  border-radius: 7px;
  color: var(--text-secondary);
  background: transparent;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.learned-toggle:hover {
  color: var(--primary);
  background: var(--primary-soft);
}

.learned-toggle.learned {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.item-date {
  margin-left: auto;
  color: var(--text-secondary);
  font-size: 12px;
}

.item-title {
  display: block;
  width: 100%;
  padding: 0;
  margin: 15px 0 8px;
  border: 0;
  color: var(--text-primary);
  background: transparent;
  font-size: 17px;
  font-weight: 750;
  line-height: 1.45;
  text-align: left;
  letter-spacing: -0.01em;
  cursor: pointer;
}

.item-title:hover {
  color: var(--primary);
}

.item-summary {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: var(--text-regular);
  font-size: 13px;
  line-height: 1.85;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.item-bottom {
  min-height: 26px;
  gap: 9px;
  margin-top: 14px;
}

.item-tags {
  flex-wrap: wrap;
  gap: 7px;
}

.item-tags :deep(.el-tag) {
  border-color: color-mix(in srgb, var(--primary) 16%, var(--border-color));
  color: var(--primary);
  background: color-mix(in srgb, var(--primary-soft) 72%, transparent);
}

.item-views {
  margin-left: auto;
  color: var(--text-secondary);
  font-size: 12px;
}

.learned-mark {
  color: var(--secondary);
  font-size: 16px;
}

@media (max-width: 620px) {
  .knowledge-item {
    padding: 15px 14px;
  }

  .item-top {
    gap: 7px;
  }

  .learned-toggle {
    padding: 4px;
    font-size: 0;
  }

  .item-date {
    font-size: 12px;
  }

  .item-title {
    font-size: 16px;
  }
}
</style>
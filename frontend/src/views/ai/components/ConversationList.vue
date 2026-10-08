<script setup lang="ts">
import { nextTick, ref } from 'vue'
import dayjs from 'dayjs'
import { ChatDotRound, Delete, Edit, Plus } from '@element-plus/icons-vue'
import type { AiConversationSummary } from '@/types'

const props = defineProps<{
  conversations: AiConversationSummary[]
  activeId: number | null
  isDraft: boolean
  loading?: boolean
}>()

const emit = defineEmits<{
  create: []
  select: [id: number]
  rename: [id: number, title: string]
  remove: [id: number]
}>()

const editingId = ref<number | null>(null)
const draftTitle = ref('')

/** 进入编辑态后自动聚焦（v-for 里的 ref 用函数式写法最稳） */
const focusInput = (element: { focus: () => void } | null) => {
  if (!element) return
  void nextTick(() => element.focus())
}

const startRename = (item: AiConversationSummary) => {
  editingId.value = item.id
  draftTitle.value = item.title
}

const commitRename = () => {
  const id = editingId.value
  if (id === null) return
  editingId.value = null
  const title = draftTitle.value.trim()
  const current = props.conversations.find((item) => item.id === id)
  if (title && title !== current?.title) emit('rename', id, title)
}

const formatTime = (value: string | null) => {
  if (!value) return ''
  const date = dayjs(value)
  const now = dayjs()
  if (date.isSame(now, 'day')) return date.format('HH:mm')
  if (date.isSame(now.subtract(1, 'day'), 'day')) return '昨天'
  return date.isSame(now, 'year') ? date.format('M月D日') : date.format('YYYY/M/D')
}
</script>

<template>
  <div class="conversation-pane">
    <el-button type="primary" class="new-button" @click="emit('create')">
      <el-icon><Plus /></el-icon>新建对话
    </el-button>

    <div v-loading="loading" class="conversation-list">
      <p v-if="!conversations.length && !isDraft" class="conversation-empty">还没有会话记录</p>

      <div v-if="isDraft" class="conversation-item is-active">
        <span class="item-icon"><el-icon><ChatDotRound /></el-icon></span>
        <div class="item-main is-static">
          <strong class="item-title">新对话</strong>
          <small class="item-preview">在右侧输入你的第一个问题</small>
        </div>
      </div>

      <div
        v-for="item in conversations"
        :key="item.id"
        class="conversation-item"
        :class="{ 'is-active': item.id === activeId && !isDraft }"
      >
        <template v-if="editingId === item.id">
          <el-input
            :ref="focusInput"
            v-model="draftTitle"
            size="small"
            maxlength="80"
            @keyup.enter="commitRename"
            @keyup.esc="editingId = null"
            @blur="commitRename"
          />
        </template>

        <template v-else>
          <button type="button" class="item-main" @click="emit('select', item.id)">
            <strong class="item-title">{{ item.title }}</strong>
            <small class="item-preview">{{ item.preview || '还没有消息' }}</small>
            <span class="item-meta">
              {{ formatTime(item.lastMessageAt) }}
              <i v-if="item.messageCount"> · {{ item.messageCount }} 条</i>
            </span>
          </button>

          <span class="item-actions">
            <el-button text size="small" title="重命名" @click.stop="startRename(item)">
              <el-icon><Edit /></el-icon>
            </el-button>
            <el-button text size="small" type="danger" title="删除" @click.stop="emit('remove', item.id)">
              <el-icon><Delete /></el-icon>
            </el-button>
          </span>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.conversation-pane {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.new-button {
  width: 100%;
}

.conversation-list {
  display: grid;
  /* 隐式 auto 列会被 nowrap 标题的整行宽度撑破（X 轴溢出、省略号失效），锁成容器宽 */
  grid-template-columns: minmax(0, 1fr);
  flex: 1;
  /* 不加 align-content 的话 grid 会把多余高度分摊给各行，条目会被拉得很高 */
  align-content: start;
  gap: 6px;
  min-height: 120px;
  overflow-x: hidden;
  overflow-y: auto;
  /* 滚动条藏起来，滚轮 / 触摸仍可滚动 */
  scrollbar-width: none;
}

.conversation-list::-webkit-scrollbar {
  display: none;
}

.conversation-empty {
  padding: 18px 6px;
  margin: 0;
  color: var(--text-secondary);
  font-size: 12px;
  text-align: center;
}

.conversation-item {
  position: relative;
  display: flex;
  align-items: center;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  transition: all 0.18s ease;
}

.conversation-item:hover {
  border-color: var(--border-soft);
  background: var(--surface-muted);
}

.conversation-item.is-active {
  border-color: color-mix(in srgb, var(--primary) 32%, var(--border-color));
  background: var(--primary-soft);
}

.conversation-item.is-active::after {
  position: absolute;
  top: 50%;
  right: 6px;
  width: 3px;
  height: 18px;
  border-radius: 99px;
  background: var(--primary);
  content: '';
  transform: translateY(-50%);
}

.item-icon {
  display: grid;
  width: 30px;
  height: 30px;
  flex: none;
  margin-left: 4px;
  place-items: center;
  border-radius: 9px;
  color: var(--primary);
  background: var(--surface);
  font-size: 15px;
}

.item-main {
  display: block;
  min-width: 0;
  flex: 1;
  padding: 9px 8px;
  border: 0;
  color: inherit;
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.item-main.is-static {
  cursor: default;
}

.item-title {
  display: block;
  overflow: hidden;
  color: var(--text-primary);
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.item-preview {
  display: block;
  overflow: hidden;
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.item-meta {
  display: block;
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 11px;
}

.item-meta i {
  font-style: normal;
}

.item-actions {
  display: none;
  flex: none;
  gap: 2px;
  padding-right: 8px;
}

.conversation-item:hover .item-actions {
  display: flex;
}

.item-actions :deep(.el-button) {
  margin-left: 0;
  padding: 4px;
}
</style>

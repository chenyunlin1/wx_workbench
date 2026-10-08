<script setup lang="ts">
import { computed, ref } from 'vue'
import dayjs from 'dayjs'
import { ElMessage } from 'element-plus'
import {
  ChatDotRound,
  CircleClose,
  CopyDocument,
  Loading,
  MagicStick,
  User,
} from '@element-plus/icons-vue'
import { renderMarkdown } from '@/utils/markdown'
import { supportsAiAction } from '@/utils/ai-actions'
import { useAiStore } from '@/stores/ai'
import { useUserStore } from '@/stores/user'
import type { AiChatAction, AiChatMessage } from '@/types'

const props = defineProps<{
  message: AiChatMessage
}>()

const userStore = useUserStore()
const aiStore = useAiStore()
const showReasoning = ref(false)
/** 同一时刻只允许执行一张卡片 */
const busyIndex = ref(-1)

const isUser = computed(() => props.message.role === 'user')
const rendered = computed(() => (isUser.value ? '' : renderMarkdown(props.message.content)))
const time = computed(() => dayjs(props.message.createdAt).format('HH:mm'))
const streaming = computed(() => props.message.status === 'streaming')
const actions = computed(() => props.message.actions ?? [])
const mcpNote = computed(() => {
  const calls = props.message.mcpCalls ?? []
  if (!calls.length) return ''
  const labels = [...new Set(calls.map((call) => call.label))].slice(0, 4).join('、')
  const failed = calls.filter((call) => !call.ok).length
  return `高驰 ${labels}${failed ? `（${failed} 次失败）` : ''}`
})

const stateText = (action: AiChatAction) => {
  if (action.status === 'done') return '已创建'
  if (action.status === 'failed') return '创建失败'
  if (action.status === 'cancelled') return '已取消'
  return supportsAiAction(action.tool) ? '待确认' : '本端暂不支持'
}

const applyAction = async (index: number, approve: boolean) => {
  if (busyIndex.value >= 0) return
  busyIndex.value = index
  try {
    const result = await aiStore.applyAction(props.message, index, approve)
    if (result.ok) ElMessage.success(result.tip)
    else if (result.tip) ElMessage.error(result.tip)
  } finally {
    busyIndex.value = -1
  }
}

const contextChips = computed(() => {
  const context = props.message.context
  if (!context) return []
  return context.sections
    .filter((section) => section.count > 0)
    .map((section) => `${section.title} ${section.count}`)
})

const copy = async () => {
  try {
    await navigator.clipboard.writeText(props.message.content)
    ElMessage.success('已复制到剪贴板')
  } catch {
    ElMessage.warning('当前浏览器不允许访问剪贴板')
  }
}
</script>

<template>
  <article class="bubble" :class="isUser ? 'is-user' : 'is-assistant'">
    <div class="avatar">
      <el-icon v-if="isUser"><User /></el-icon>
      <el-icon v-else><ChatDotRound /></el-icon>
    </div>

    <div class="body">
      <header class="meta">
        <strong>{{ isUser ? userStore.displayName : 'LifeOS AI' }}</strong>
        <span class="time">{{ time }}</span>
        <span v-if="!isUser && message.model" class="model">{{ message.model }}</span>
        <span v-if="!isUser && message.elapsedMs" class="elapsed">
          {{ (message.elapsedMs / 1000).toFixed(1) }}s
        </span>
        <span v-if="!isUser && mcpNote" class="mcp" :title="mcpNote">已读取 {{ mcpNote }}</span>
        <span v-if="streaming" class="status">
          <el-icon class="spin"><Loading /></el-icon>
          生成中
        </span>
      </header>

      <div v-if="message.reasoning" class="reasoning">
        <button type="button" class="reasoning-toggle" @click="showReasoning = !showReasoning">
          <el-icon><MagicStick /></el-icon>
          {{ showReasoning ? '收起思考过程' : '查看思考过程' }}
        </button>
        <pre v-if="showReasoning" class="reasoning-text">{{ message.reasoning }}</pre>
      </div>

      <div v-if="isUser" class="content plain">{{ message.content }}</div>
      <div
        v-else-if="message.content"
        class="content md-body"
        v-html="rendered"
      />
      <div v-else-if="streaming && !actions.length" class="content placeholder">正在思考…</div>

      <section v-if="!isUser && actions.length" class="actions">
        <article
          v-for="(action, index) in actions"
          :key="`${action.tool}-${index}`"
          class="action"
          :class="`action-${action.status}`"
        >
          <header class="action-head">
            <el-icon><MagicStick /></el-icon>
            <strong>{{ action.label }}</strong>
            <span class="action-state">{{ stateText(action) }}</span>
          </header>

          <dl class="action-fields">
            <div v-for="field in action.fields" :key="field.label" class="action-field">
              <dt>{{ field.label }}</dt>
              <dd>{{ field.value }}</dd>
            </div>
          </dl>

          <p v-if="action.error" class="action-error">{{ action.error }}</p>

          <div
            v-if="action.status === 'pending' && supportsAiAction(action.tool)"
            class="action-buttons"
          >
            <el-button size="small" :disabled="busyIndex >= 0" @click="applyAction(index, false)">
              取消
            </el-button>
            <el-button
              size="small"
              type="primary"
              :loading="busyIndex === index"
              :disabled="busyIndex >= 0 && busyIndex !== index"
              @click="applyAction(index, true)"
            >
              确认创建
            </el-button>
          </div>
        </article>
      </section>

      <p v-if="message.error" class="error-note">
        <el-icon><CircleClose /></el-icon>
        {{ message.error }}
      </p>

      <footer v-if="!isUser && (contextChips.length || message.content)" class="foot">
        <div v-if="contextChips.length" class="context-chips">
          <span class="context-label">已读取</span>
          <span v-for="chip in contextChips" :key="chip" class="chip">{{ chip }}</span>
        </div>
        <el-button v-if="message.content" link size="small" @click="copy">
          <el-icon><CopyDocument /></el-icon>
          复制
        </el-button>
      </footer>
    </div>
  </article>
</template>

<style scoped lang="scss">
.bubble {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.bubble.is-user {
  flex-direction: row-reverse;
}

.avatar {
  display: grid;
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 12px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 18px;
}

.bubble.is-user .avatar {
  color: #fff;
  background: var(--primary);
}

.body {
  min-width: 0;
  max-width: min(860px, 78%);
  padding: 12px 15px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
}

.bubble.is-user .body {
  background: linear-gradient(135deg, color-mix(in srgb, var(--primary-soft) 75%, var(--surface)), var(--surface));
}

.meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  margin-bottom: 8px;
  font-size: 13px;
  color: var(--text-secondary);
}

.meta strong {
  color: var(--text-primary);
  font-size: 13px;
}

.model {
  padding: 1px 7px;
  border-radius: 99px;
  background: var(--surface-muted);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.mcp {
  max-width: 260px;
  padding: 1px 7px;
  overflow: hidden;
  border-radius: 99px;
  color: var(--primary-strong);
  background: var(--primary-soft);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.status {
  display: inline-flex;
  gap: 4px;
  align-items: center;
  color: var(--primary);
}

.spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.content.plain {
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.85;
  white-space: pre-wrap;
  word-break: break-word;
}

.content.placeholder {
  color: var(--text-secondary);
  font-size: 14px;
}

.reasoning {
  margin-bottom: 10px;
}

.reasoning-toggle {
  display: inline-flex;
  gap: 5px;
  align-items: center;
  padding: 3px 9px;
  border-radius: 99px;
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 12%, transparent);
  font-size: 13px;
  cursor: pointer;
}

.reasoning-text {
  max-height: 220px;
  padding: 10px 12px;
  margin: 8px 0 0;
  overflow: auto;
  border-radius: var(--radius-sm);
  color: var(--text-secondary);
  background: var(--surface-muted);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 13px;
  line-height: 1.7;
  white-space: pre-wrap;
}

.actions {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 10px;
}

.action {
  padding: 10px 12px;
  border: 1px solid var(--border-soft);
  border-left: 3px solid var(--primary);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.action-done {
  border-left-color: var(--success, var(--secondary));
  opacity: 0.75;
}

.action-cancelled,
.action-failed {
  border-left-color: var(--text-secondary);
  opacity: 0.75;
}

.action-head {
  display: flex;
  gap: 7px;
  align-items: center;
  color: var(--text-primary);
  font-size: 13px;
}

.action-state {
  padding: 1px 8px;
  border-radius: 99px;
  color: var(--primary);
  background: color-mix(in srgb, var(--primary) 14%, transparent);
  font-size: 12px;
}

.action-done .action-state {
  color: var(--secondary);
  background: color-mix(in srgb, var(--secondary) 16%, transparent);
}

.action-fields {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 18px;
  margin: 8px 0 0;
}

.action-field {
  display: flex;
  gap: 5px;
  font-size: 13px;
}

.action-field dt {
  color: var(--text-secondary);
}

.action-field dd {
  margin: 0;
  color: var(--text-primary);
  word-break: break-word;
}

.action-error {
  margin: 7px 0 0;
  color: var(--danger);
  font-size: 12px;
}

.action-buttons {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
  margin-top: 10px;
}

.error-note {
  display: flex;
  gap: 6px;
  align-items: center;
  padding: 7px 10px;
  margin: 10px 0 0;
  border-radius: var(--radius-sm);
  color: var(--danger);
  background: color-mix(in srgb, var(--danger) 10%, transparent);
  font-size: 13px;
}

.foot {
  display: flex;
  gap: 10px;
  align-items: center;
  justify-content: space-between;
  margin-top: 10px;
  padding-top: 9px;
  border-top: 1px dashed var(--border-soft);
}

.context-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  align-items: center;
}

.context-label {
  color: var(--text-secondary);
  font-size: 13px;
}

.chip {
  padding: 1px 7px;
  border-radius: 99px;
  color: var(--secondary);
  background: color-mix(in srgb, var(--secondary) 13%, transparent);
  font-size: 13px;
}

.md-body {
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.85;
  word-break: break-word;
}

.md-body :deep(p) {
  margin: 0 0 8px;
}

.md-body :deep(p:last-child) {
  margin-bottom: 0;
}

.md-body :deep(h3),
.md-body :deep(h4),
.md-body :deep(h5),
.md-body :deep(h6) {
  margin: 12px 0 7px;
  color: var(--text-primary);
  font-size: 14px;
}

.md-body :deep(ul),
.md-body :deep(ol) {
  padding-left: 20px;
  margin: 6px 0;
}

.md-body :deep(li) {
  margin-bottom: 3px;
}

.md-body :deep(blockquote) {
  padding: 2px 0 2px 11px;
  margin: 8px 0;
  border-left: 3px solid var(--primary);
  color: var(--text-secondary);
}

.md-body :deep(blockquote p) {
  margin: 2px 0;
}

.md-body :deep(.md-code) {
  padding: 1px 5px;
  border-radius: 5px;
  color: var(--primary-strong);
  background: var(--surface-muted);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 13px;
}

.md-body :deep(.md-pre) {
  position: relative;
  padding: 11px 12px;
  margin: 9px 0;
  overflow: auto;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.md-body :deep(.md-pre code) {
  color: var(--text-primary);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 13px;
  white-space: pre;
}

.md-body :deep(.md-lang) {
  display: block;
  margin-bottom: 6px;
  color: var(--text-secondary);
  font-size: 12px;
  text-transform: uppercase;
}

.md-body :deep(.md-table-wrap) {
  margin: 9px 0;
  overflow-x: auto;
}

.md-body :deep(.md-table) {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.md-body :deep(.md-table th),
.md-body :deep(.md-table td) {
  padding: 6px 10px;
  border: 1px solid var(--border-soft);
  text-align: left;
}

.md-body :deep(.md-table th) {
  color: var(--text-primary);
  background: var(--surface-muted);
}

.md-body :deep(.md-link) {
  color: var(--primary);
  text-decoration: underline;
}

.md-body :deep(hr) {
  margin: 12px 0;
  border: 0;
  border-top: 1px solid var(--border-soft);
}

@media (max-width: 760px) {
  .body {
    max-width: 100%;
  }
}
</style>

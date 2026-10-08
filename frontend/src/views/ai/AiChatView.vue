<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  ChatDotRound,
  Key,
  Plus,
  Position,
  Setting,
  VideoPause,
} from '@element-plus/icons-vue'
import ChatBubble from './components/ChatBubble.vue'
import ConversationList from './components/ConversationList.vue'
import AiSettingsDialog from './components/AiSettingsDialog.vue'
import { useAiStore } from '@/stores/ai'
import { useUserStore } from '@/stores/user'
import { AI_SCOPE_OPTIONS } from './ai-scopes'
import type { AiConversationSummary } from '@/types'

const aiStore = useAiStore()
const userStore = useUserStore()
const route = useRoute()
const router = useRouter()

const draft = ref('')
const settingsOpen = ref(false)
const listRef = ref<HTMLElement | null>(null)
const conversationDrawer = ref(false)
const isMobile = ref(false)
let mediaQuery: MediaQueryList | null = null

const SUGGESTIONS = [
  '帮我梳理今天剩下的安排，并指出时间冲突',
  '这个月我的支出结构怎么样？给 3 条省钱建议',
  '根据我的知识库出 3 道面试题并给出答案要点',
  '我的习惯坚持情况如何？哪个最容易中断',
]

const messages = computed(() => aiStore.messages)
const canSend = computed(() => Boolean(draft.value.trim()) && !aiStore.sending)

// 用单个标签表达两种状态，避免 v-if / v-else 切换时短暂出现两个节点
const contextTag = computed(() =>
  aiStore.contextScope.length
    ? {
        text: `上下文 ${aiStore.contextScope.length}/${AI_SCOPE_OPTIONS.length} 类`,
        type: 'primary' as const,
      }
    : { text: '未携带平台数据', type: 'info' as const },
)

const stopOrSend = () => {
  if (aiStore.sending) {
    aiStore.stop()
    return
  }
  void submit()
}

const scrollToBottom = async () => {
  await nextTick()
  const element = listRef.value
  if (element) element.scrollTop = element.scrollHeight
}

watch(
  () => {
    const last = aiStore.messages[aiStore.messages.length - 1]
    return `${aiStore.messages.length}-${last?.content.length ?? 0}-${last?.reasoning.length ?? 0}`
  },
  scrollToBottom,
)

/** 切换会话后滚到底部 */
watch(
  () => aiStore.activeConversationId,
  () => void scrollToBottom(),
)

const syncViewport = (event?: MediaQueryListEvent) => {
  isMobile.value = event ? event.matches : Boolean(mediaQuery?.matches)
  if (!isMobile.value) conversationDrawer.value = false
}

onMounted(async () => {
  mediaQuery = window.matchMedia('(max-width: 900px)')
  syncViewport()
  mediaQuery.addEventListener('change', syncViewport)

  if (!aiStore.settings) await aiStore.loadSettings()
  await aiStore.loadConversations(true)
  if (!aiStore.hasApiKey) {
    settingsOpen.value = true
    ElMessage.info('首次使用请先填写 DeepSeek API Key')
  }
  // 从「跑步专项」等页面带问题跳过来时，填进输入框但不直接发送
  const ask = route.query.ask
  if (typeof ask === 'string' && ask.trim()) {
    draft.value = ask
    await router.replace({ query: {} })
  }
  await scrollToBottom()
})

onBeforeUnmount(() => mediaQuery?.removeEventListener('change', syncViewport))

const submit = async () => {
  if (!canSend.value) return
  const content = draft.value
  draft.value = ''
  await aiStore.send(content)
}

const handleCreate = async () => {
  try {
    await aiStore.createConversation()
    conversationDrawer.value = false
    await scrollToBottom()
  } catch {
    // 拦截器已提示
  }
}

const handleSelect = async (id: number) => {
  conversationDrawer.value = false
  await aiStore.selectConversation(id)
}

const handleRename = async (id: number, title: string) => {
  try {
    await aiStore.renameConversation(id, title)
    ElMessage.success('会话已重命名')
  } catch {
    // 拦截器已提示
  }
}

const handleRemove = async (id: number) => {
  const target = aiStore.conversations.find((item) => item.id === id)
  await ElMessageBox.confirm(
    `删除后「${target?.title ?? '该会话'}」的聊天记录将无法恢复，确定继续吗？`,
    '删除会话',
    { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' },
  )
  await aiStore.removeConversation(id)
  await scrollToBottom()
  ElMessage.success('会话已删除')
}

const listProps = computed(() => ({
  conversations: aiStore.conversations as AiConversationSummary[],
  activeId: aiStore.activeConversationId,
  isDraft: aiStore.isDraft,
  loading: aiStore.loadingConversations,
}))
</script>

<template>
  <section class="ai-page">
    <header class="page-head">
      <div class="head-main">
        <span class="head-icon"><el-icon><ChatDotRound /></el-icon></span>
        <div>
          <h2>AI 助手</h2>
          <p>
            已接入 DeepSeek，可读取你在 LifeOS 中的日程、习惯、学习、知识库、面试、财务、健康与待买数据。
          </p>
        </div>
      </div>

      <div class="head-actions">
        <el-tag v-if="aiStore.settings" size="small" effect="plain" round>
          {{ aiStore.model }}
        </el-tag>
        <el-tag
          size="small"
          round
          :type="aiStore.hasApiKey ? 'success' : 'warning'"
          effect="light"
        >
          {{ aiStore.hasApiKey ? '密钥已配置' : '未配置密钥' }}
        </el-tag>
        <el-tag size="small" round effect="plain" :type="contextTag.type">
          {{ contextTag.text }}
        </el-tag>
        <el-button v-if="isMobile" @click="conversationDrawer = true">
          <el-icon><ChatDotRound /></el-icon>
          会话
        </el-button>
        <el-button type="primary" @click="settingsOpen = true">
          <el-icon><Setting /></el-icon>
          设置
        </el-button>
      </div>
    </header>

    <el-alert
      v-if="aiStore.settings && !aiStore.hasApiKey"
      class="key-alert"
      type="warning"
      :closable="false"
      show-icon
    >
      <template #title>还需要配置 DeepSeek API Key 才能开始对话</template>
      <div class="alert-body">
        <span>密钥只保存在你自己的数据库里，接口返回时始终脱敏。</span>
        <el-button size="small" type="primary" @click="settingsOpen = true">
          <el-icon><Key /></el-icon>
          去填写密钥
        </el-button>
      </div>
    </el-alert>

    <div class="ai-body">
      <aside v-if="!isMobile" class="conversation-aside">
        <ConversationList
          v-bind="listProps"
          @create="handleCreate"
          @select="handleSelect"
          @rename="handleRename"
          @remove="handleRemove"
        />
      </aside>

      <div class="chat-pane">
        <div class="chat-title">
          <strong>{{ aiStore.activeTitle }}</strong>
          <span v-if="aiStore.isDraft">说出你的第一个问题，会话会自动保存</span>
          <span v-else-if="aiStore.activeConversation">
            共 {{ aiStore.activeConversation.messageCount }} 条消息
          </span>
        </div>

        <div ref="listRef" v-loading="aiStore.loadingMessages" class="chat-list">
          <div v-if="!messages.length" class="empty">
            <span class="empty-icon"><el-icon><ChatDotRound /></el-icon></span>
            <h3>{{ userStore.displayName }}，想聊点什么？</h3>
            <p>助手已经在后台读取了你的平台数据，所有回答都基于真实记录。</p>
            <div class="suggestions">
              <button
                v-for="item in SUGGESTIONS"
                :key="item"
                type="button"
                class="suggestion"
                @click="draft = item"
              >
                {{ item }}
              </button>
            </div>
          </div>

          <ChatBubble v-for="message in messages" :key="message.id" :message="message" />
        </div>

        <footer class="composer">
          <el-input
            v-model="draft"
            type="textarea"
            :autosize="{ minRows: 2, maxRows: 6 }"
            resize="none"
            placeholder="向 AI 助手提问，例如：本周还有哪些没完成的学习任务？（Enter 发送，Shift + Enter 换行）"
            @keydown.enter.exact.prevent="submit"
          />
          <div class="composer-bar">
            <span class="hint">
              {{ aiStore.sending ? '正在生成，可随时停止' : '回答基于你的平台数据生成，重要决策请自行核对' }}
            </span>
            <el-button
              :type="aiStore.sending ? 'danger' : 'primary'"
              :disabled="!aiStore.sending && !canSend"
              @click="stopOrSend"
            >
              <el-icon><component :is="aiStore.sending ? VideoPause : Position" /></el-icon>
              {{ aiStore.sending ? '停止生成' : '发送' }}
            </el-button>
          </div>
        </footer>
      </div>
    </div>

    <el-drawer v-model="conversationDrawer" direction="ltr" :with-header="false" size="min(84vw, 300px)">
      <div class="drawer-body">
        <ConversationList
          v-bind="listProps"
          @create="handleCreate"
          @select="handleSelect"
          @rename="handleRename"
          @remove="handleRemove"
        />
      </div>
    </el-drawer>

    <AiSettingsDialog v-model="settingsOpen" />
  </section>
</template>

<style scoped lang="scss">
.ai-page {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 150px);
  min-height: 480px;
}

.ai-body {
  display: flex;
  flex: 1;
  gap: 14px;
  min-height: 0;
}

.conversation-aside {
  display: flex;
  width: 272px;
  flex: none;
  min-height: 0;
}

.conversation-aside > :deep(.conversation-pane),
.conversation-aside :deep(.conversation-pane) {
  width: 100%;
}

.chat-pane {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}

.chat-title {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: baseline;
  padding: 0 4px 10px;
}

.chat-title strong {
  color: var(--text-primary);
  font-size: 15px;
}

.chat-title span {
  color: var(--text-secondary);
  font-size: 12px;
}

.drawer-body {
  height: 100%;
  padding: 14px;
  background: var(--surface);
}

.drawer-body :deep(.conversation-pane) {
  height: 100%;
  border: 0;
  box-shadow: none;
  background: transparent;
}

.page-head {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  margin-bottom: 14px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.head-main {
  display: flex;
  gap: 13px;
  align-items: center;
}

.head-icon {
  display: grid;
  width: 44px;
  height: 44px;
  flex-shrink: 0;
  place-items: center;
  border-radius: 14px;
  color: #fff;
  background: var(--primary);
  font-size: 22px;
  box-shadow: 0 8px 20px color-mix(in srgb, var(--primary) 32%, transparent);
}

.head-main h2 {
  margin: 0 0 3px;
  color: var(--text-primary);
  font-size: 19px;
}

.head-main p {
  margin: 0;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.6;
}

.head-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}

.key-alert {
  margin-bottom: 14px;
}

.alert-body {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  justify-content: space-between;
  font-size: 13px;
}

.chat-list {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 16px;
  min-height: 0;
  padding: 18px;
  overflow-y: auto;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--surface) 82%, transparent);
}

.empty {
  display: grid;
  max-width: 620px;
  margin: auto;
  place-items: center;
  text-align: center;
}

.empty-icon {
  display: grid;
  width: 62px;
  height: 62px;
  margin-bottom: 14px;
  place-items: center;
  border-radius: 20px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 29px;
}

.empty h3 {
  margin: 0 0 8px;
  color: var(--text-primary);
  font-size: 19px;
}

.empty p {
  margin: 0 0 18px;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.8;
}

.suggestions {
  display: grid;
  width: 100%;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 9px;
}

.suggestion {
  padding: 11px 13px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  color: var(--text-regular);
  background: var(--surface-raised);
  font-size: 13px;
  text-align: left;
  cursor: pointer;
  transition: all 0.18s ease;
}

.suggestion:hover {
  border-color: color-mix(in srgb, var(--primary) 40%, var(--border-color));
  color: var(--primary);
  transform: translateY(-2px);
}

.composer {
  padding: 14px 16px 12px;
  margin-top: 14px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.composer :deep(.el-textarea__inner) {
  border: 0;
  box-shadow: none;
  background: transparent;
  font-size: 14px;
}

.composer-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  justify-content: space-between;
  padding-top: 8px;
  margin-top: 6px;
  border-top: 1px dashed var(--border-soft);
}

.hint {
  color: var(--text-secondary);
  font-size: 13px;
}

@media (max-width: 860px) {
  .ai-page {
    height: auto;
    min-height: 0;
  }

  .chat-list {
    max-height: 62vh;
  }

  .suggestions {
    grid-template-columns: 1fr;
  }
}
</style>

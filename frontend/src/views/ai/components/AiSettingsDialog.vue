<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Connection,
  Delete,
  Document,
  Key,
  Refresh,
  Setting,
} from '@element-plus/icons-vue'
import { useAiStore } from '@/stores/ai'
import { AI_SCOPE_OPTIONS } from '../ai-scopes'
import type { AiContextScope, AiSettingsPayload, AiTestResult } from '@/types'

const props = defineProps<{
  modelValue: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  saved: []
}>()

const visible = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const SCOPE_OPTIONS = AI_SCOPE_OPTIONS

const MODEL_OPTIONS = ['deepseek-chat', 'deepseek-reasoner']

const aiStore = useAiStore()
const activeTab = ref('model')
const testResult = ref<AiTestResult | null>(null)

const form = reactive({
  apiKey: '',
  baseUrl: 'https://api.deepseek.com',
  model: 'deepseek-chat',
  temperature: 0.7,
  systemPrompt: '',
  contextScope: [] as AiContextScope[],
})

const settings = computed(() => aiStore.settings)

const keyStatus = computed(() => {
  if (form.apiKey.trim()) return '将保存新的密钥'
  if (!settings.value?.hasApiKey) return '尚未配置，保存后即可对话'
  if (settings.value.keySource === 'env') return '来自后端 .env 的 DEEPSEEK_API_KEY'
  return `已保存：${settings.value.apiKeyPreview}`
})

const contextPreview = computed(() => aiStore.contextPreview)
const hasScope = computed(() => form.contextScope.length > 0)

const syncForm = () => {
  const current = aiStore.settings
  if (!current) return
  form.apiKey = ''
  form.baseUrl = current.baseUrl
  form.model = current.model
  form.temperature = current.temperature
  form.systemPrompt = current.systemPrompt
  form.contextScope = [...current.contextScope]
}

const refreshPreview = () => {
  if (!hasScope.value) {
    aiStore.contextPreview = null
    return
  }
  void aiStore.loadContext(form.contextScope, true)
}

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    testResult.value = null
    if (!aiStore.settings) await aiStore.loadSettings()
    syncForm()
    refreshPreview()
  },
)

watch(
  () => form.contextScope.length,
  (length) => {
    if (!length) aiStore.contextPreview = null
  },
)

const save = async () => {
  const payload: AiSettingsPayload = {
    baseUrl: form.baseUrl.trim(),
    model: form.model.trim(),
    temperature: form.temperature,
    systemPrompt: form.systemPrompt,
    contextScope: form.contextScope,
  }
  if (form.apiKey.trim()) payload.apiKey = form.apiKey.trim()

  try {
    await aiStore.saveSettings(payload)
    form.apiKey = ''
    ElMessage.success('AI 助手配置已保存')
    emit('saved')
    visible.value = false
  } catch {
    // 拦截器已提示
  }
}

const removeKey = async () => {
  try {
    await aiStore.removeApiKey()
    form.apiKey = ''
    ElMessage.success('已清除保存的 API Key')
  } catch {
    // 拦截器已提示
  }
}

const runTest = async () => {
  testResult.value = null
  try {
    testResult.value = await aiStore.testConnection({
      apiKey: form.apiKey.trim() || undefined,
      baseUrl: form.baseUrl.trim(),
      model: form.model.trim(),
    })
  } catch (error) {
    testResult.value = {
      ok: false,
      model: form.model,
      baseUrl: form.baseUrl,
      latencyMs: 0,
      message: error instanceof Error ? error.message : '测试失败',
    }
  }
}

const restorePrompt = () => {
  form.systemPrompt = ''
}
</script>

<template>
  <el-dialog
    v-model="visible"
    title="AI 助手设置"
    width="min(760px, 94vw)"
    top="6vh"
    class="ai-settings-dialog"
  >
    <el-tabs v-model="activeTab">
      <el-tab-pane name="model">
        <template #label>
          <span class="tab-label"><el-icon><Setting /></el-icon> 模型配置</span>
        </template>

        <el-form label-position="top" class="settings-form">
          <el-form-item label="DeepSeek API Key">
            <el-input
              v-model="form.apiKey"
              type="password"
              show-password
              clearable
              autocomplete="off"
              :placeholder="settings?.apiKeyPreview || 'sk-...'"
            />
            <p class="field-hint">
              <el-icon><Key /></el-icon>
              {{ keyStatus }}
              <a href="https://platform.deepseek.com/api_keys" target="_blank" rel="noopener">
                获取密钥
              </a>
            </p>
          </el-form-item>

          <div class="field-row">
            <el-form-item label="接口地址">
              <el-input v-model="form.baseUrl" placeholder="https://api.deepseek.com" />
            </el-form-item>
            <el-form-item label="模型">
              <el-select
                v-model="form.model"
                filterable
                allow-create
                default-first-option
                placeholder="deepseek-chat"
              >
                <el-option v-for="item in MODEL_OPTIONS" :key="item" :label="item" :value="item" />
              </el-select>
            </el-form-item>
          </div>

          <el-form-item :label="`回答随机度（temperature）：${form.temperature}`">
            <el-slider v-model="form.temperature" :min="0" :max="2" :step="0.1" />
          </el-form-item>

          <el-form-item label="系统提示词">
            <el-input
              v-model="form.systemPrompt"
              type="textarea"
              :rows="4"
              resize="vertical"
              placeholder="留空使用内置提示词（要求模型只基于平台真实数据回答）"
            />
            <div class="field-actions">
              <el-button link size="small" @click="restorePrompt">
                <el-icon><Refresh /></el-icon>
                恢复内置提示词
              </el-button>
            </div>
          </el-form-item>

          <el-form-item>
            <el-button :loading="aiStore.testing" @click="runTest">
              <el-icon><Connection /></el-icon>
              测试连接
            </el-button>
            <el-button
              v-if="settings?.hasApiKey && settings.keySource === 'user'"
              link
              type="danger"
              @click="removeKey"
            >
              <el-icon><Delete /></el-icon>
              清除已保存的密钥
            </el-button>
          </el-form-item>

          <el-alert
            v-if="testResult"
            :type="testResult.ok ? 'success' : 'error'"
            :closable="false"
            show-icon
            class="test-result"
          >
            <template #title>{{ testResult.message }}</template>
            <span v-if="testResult.ok && testResult.reply" class="test-reply">
              模型回复：{{ testResult.reply }}
            </span>
            <span v-else-if="!testResult.ok" class="test-reply">
              接口地址：{{ testResult.baseUrl }}
            </span>
          </el-alert>
        </el-form>
      </el-tab-pane>

      <el-tab-pane name="context">
        <template #label>
          <span class="tab-label"><el-icon><Document /></el-icon> 数据上下文</span>
        </template>

        <p class="context-intro">
          每次提问时，后端会把下列平台数据汇总成快照，随系统提示词一起发送给模型。取消勾选即可让某些数据不参与本次对话。
        </p>

        <el-checkbox-group v-model="form.contextScope" class="scope-group">
          <label v-for="item in SCOPE_OPTIONS" :key="item.value" class="scope-item">
            <el-checkbox :value="item.value">{{ item.label }}</el-checkbox>
            <span>{{ item.hint }}</span>
          </label>
        </el-checkbox-group>

        <div class="scope-actions">
          <el-button link size="small" @click="form.contextScope = SCOPE_OPTIONS.map((item) => item.value)">
            全选
          </el-button>
          <el-button link size="small" @click="form.contextScope = []">全部取消</el-button>
          <el-button link size="small" :loading="aiStore.loadingContext" @click="refreshPreview">
            <el-icon><Refresh /></el-icon>
            刷新预览
          </el-button>
          <span v-if="contextPreview" class="preview-meta">
            快照 {{ contextPreview.length }} 字 · {{ contextPreview.sections.filter((s) => s.count > 0).length }} 类数据有内容
          </span>
        </div>

        <pre v-if="contextPreview" class="context-preview">{{ contextPreview.text }}</pre>
        <el-alert
          v-else-if="!hasScope"
          type="info"
          :closable="false"
          show-icon
          title="未勾选任何数据范围，对话时不会把平台数据发送给模型"
        />
        <el-empty v-else description="暂无快照，点击「刷新预览」生成" :image-size="70" />
      </el-tab-pane>
    </el-tabs>

    <template #footer>
      <el-button @click="visible = false">取消</el-button>
      <el-button type="primary" :loading="aiStore.saving" @click="save">保存设置</el-button>
    </template>
  </el-dialog>
</template>

<style scoped lang="scss">
.tab-label {
  display: inline-flex;
  gap: 5px;
  align-items: center;
}

.settings-form {
  padding-top: 4px;
}

.field-row {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 14px;
}

.field-hint {
  display: flex;
  gap: 6px;
  align-items: center;
  margin: 6px 0 0;
  color: var(--text-secondary);
  font-size: 13px;
}

.field-hint a {
  color: var(--primary);
  text-decoration: underline;
}

.field-actions {
  margin-top: 4px;
}

.test-result {
  margin-top: 2px;
}

.test-reply {
  color: var(--text-secondary);
  font-size: 13px;
}

.context-intro {
  margin: 0 0 14px;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.8;
}

.scope-group {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px 16px;
}

.scope-item {
  display: flex;
  gap: 8px;
  align-items: center;
  padding: 7px 10px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.scope-item span {
  color: var(--text-secondary);
  font-size: 13px;
}

.scope-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  margin: 12px 0 8px;
}

.preview-meta {
  color: var(--text-secondary);
  font-size: 13px;
}

.context-preview {
  max-height: 320px;
  padding: 12px 14px;
  margin: 0;
  overflow: auto;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-sm);
  color: var(--text-regular);
  background: var(--surface-muted);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 13px;
  line-height: 1.75;
  white-space: pre-wrap;
}

@media (max-width: 760px) {
  .field-row,
  .scope-group {
    grid-template-columns: 1fr;
  }
}
</style>

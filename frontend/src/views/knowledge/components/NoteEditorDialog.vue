<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { EditPen, Plus } from '@element-plus/icons-vue'
import type { KnowledgePayload, KnowledgeType } from '@/types'

const visible = defineModel<boolean>({ required: true })
const props = defineProps<{ tagOptions: string[]; loading?: boolean }>()
const emit = defineEmits<{
  submit: [payload: KnowledgePayload & { type: KnowledgeType; title: string; content: string }]
}>()

interface NoteForm {
  type: KnowledgeType
  title: string
  content: string
  tags: string[]
}

const formRef = ref<FormInstance>()
const form = reactive<NoteForm>({ type: 'note', title: '', content: '', tags: [] })
const rules: FormRules<NoteForm> = {
  type: [{ required: true, message: '请选择类型', trigger: 'change' }],
  title: [
    { required: true, message: '请输入标题', trigger: 'blur' },
    { max: 255, message: '标题不能超过 255 个字符', trigger: 'blur' },
  ],
  content: [{ required: true, message: '请输入内容', trigger: 'blur' }],
}

const reset = () => {
  form.type = 'note'
  form.title = ''
  form.content = ''
  form.tags = []
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  emit('submit', {
    type: form.type,
    title: form.title.trim(),
    content: form.content.trim(),
    tags: [...form.tags],
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    title="记一条知识笔记"
    width="min(92vw, 660px)"
    append-to-body
    destroy-on-close
    class="knowledge-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><EditPen /></el-icon></span>
        <div>
          <strong>记一条知识笔记</strong>
          <small>把零散知识沉淀成可检索的卡片</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="类型" prop="type">
        <el-radio-group v-model="form.type" class="type-selector">
          <el-radio-button value="note">✨ 笔记</el-radio-button>
          <el-radio-button value="qa">❓ 问答</el-radio-button>
        </el-radio-group>
      </el-form-item>
      <el-form-item label="标题" prop="title">
        <el-input v-model="form.title" size="large" maxlength="255" show-word-limit placeholder="例如：Vue3 响应式原理" />
      </el-form-item>
      <el-form-item label="内容" prop="content">
        <el-input v-model="form.content" type="textarea" :rows="7" resize="vertical" placeholder="记录核心概念、代码示例、问题原因或解决过程……" />
      </el-form-item>
      <el-form-item label="技术标签">
        <el-select
          v-model="form.tags"
          multiple
          filterable
          allow-create
          default-first-option
          collapse-tags
          collapse-tags-tooltip
          :max-collapse-tags="5"
          placeholder="选择或输入标签"
          style="width: 100%"
        >
          <el-option v-for="tag in props.tagOptions" :key="tag" :label="tag" :value="tag" />
        </el-select>
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button @click="visible = false">取消</el-button>
      <el-button type="primary" :loading="loading" @click="submit">
        <el-icon><Plus /></el-icon>
        保存笔记
      </el-button>
    </template>
  </el-dialog>
</template>

<style scoped lang="scss">
.dialog-heading { display: flex; align-items: center; gap: 11px; }
.dialog-icon { display: grid; width: 38px; height: 38px; place-items: center; border-radius: 11px; color: var(--primary); background: var(--primary-soft); font-size: 19px; }
.dialog-heading strong, .dialog-heading small { display: block; }
.dialog-heading strong { color: var(--text-primary); font-size: 16px; }
.dialog-heading small { margin-top: 3px; color: var(--text-secondary); font-size: 12px; }
.type-selector { display: flex; width: 100%; }
.type-selector :deep(.el-radio-button) { flex: 1; }
.type-selector :deep(.el-radio-button__inner) { width: 100%; }
@media (max-width: 600px) { .type-selector :deep(.el-radio-button__inner) { padding-right: 8px; padding-left: 8px; font-size: 13px; } }
</style>
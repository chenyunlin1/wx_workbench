<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, Monitor } from '@element-plus/icons-vue'
import type { OpsCommand, OpsCommandPayload } from '@/types'

const CATEGORY_OPTIONS = ['Linux', 'systemd', 'MySQL', 'Nginx', '部署', '网络', '其他']

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  item?: OpsCommand | null
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: OpsCommandPayload]
}>()

const formRef = ref<FormInstance>()
const form = reactive({
  title: '',
  command: '',
  description: '',
  category: '其他',
})

const rules: FormRules = {
  title: [
    { required: true, message: '请输入命令名称', trigger: 'blur' },
    { max: 120, message: '名称最多 120 个字', trigger: 'blur' },
  ],
  command: [
    { required: true, message: '请输入命令内容', trigger: 'blur' },
    { max: 2000, message: '命令最多 2000 个字', trigger: 'blur' },
  ],
}

const reset = () => {
  form.title = props.item?.title ?? ''
  form.command = props.item?.command ?? ''
  form.description = props.item?.description ?? ''
  form.category = props.item?.category ?? '其他'
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  emit('save', {
    title: form.title.trim(),
    command: form.command.trim(),
    description: form.description.trim(),
    category: form.category.trim() || '其他',
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    width="min(430px, 92vw)"
    align-center
    append-to-body
    destroy-on-close
    class="ops-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><Monitor /></el-icon></span>
        <div>
          <strong>{{ item ? '编辑命令' : '新增命令' }}</strong>
          <small>{{ item ? '修改命令内容、说明或分类' : '把常用的那几条先记下来' }}</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="命令名称" prop="title">
        <el-input v-model="form.title" maxlength="120" placeholder="如 查看端口监听情况" />
      </el-form-item>

      <el-form-item label="命令内容" prop="command">
        <el-input
          v-model="form.command"
          type="textarea"
          :rows="3"
          maxlength="2000"
          class="code-input"
          placeholder="如 ss -tlnp，多行命令也可以"
        />
      </el-form-item>

      <el-form-item label="说明（选填）">
        <el-input
          v-model="form.description"
          type="textarea"
          :rows="2"
          maxlength="2000"
          placeholder="这条命令是做什么的、什么时候用"
        />
      </el-form-item>

      <el-form-item label="分类">
        <el-select v-model="form.category" filterable allow-create default-first-option class="category-select">
          <el-option v-for="option in CATEGORY_OPTIONS" :key="option" :label="option" :value="option" />
        </el-select>
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button type="primary" size="large" :loading="saving" class="save-button" @click="submit">
        <el-icon><Check /></el-icon>保存
      </el-button>
    </template>
  </el-dialog>
</template>

<style scoped lang="scss">
.dialog-heading {
  display: flex;
  align-items: center;
  gap: 11px;
}

.dialog-icon {
  display: grid;
  width: 39px;
  height: 39px;
  place-items: center;
  border-radius: 12px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 19px;
}

.dialog-heading strong,
.dialog-heading small {
  display: block;
}

.dialog-heading strong {
  color: var(--text-primary);
  font-size: 16px;
}

.dialog-heading small {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.code-input :deep(.el-textarea__inner) {
  font-family: 'JetBrains Mono', 'Cascadia Code', Consolas, 'Courier New', monospace;
  font-size: 13px;
}

.category-select {
  width: 100%;
}

.save-button {
  width: 100%;
  height: 45px;
  border: 0;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
}
</style>

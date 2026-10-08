<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, Sunny } from '@element-plus/icons-vue'
import type { HabitStatItem, HabitPayload } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  habit?: HabitStatItem | null
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: HabitPayload]
}>()

const ICONS = ['🌅', '📖', '🏃', '🧘', '💧', '🥗', '😴', '✍️', '🎸', '🧹', '☀️', '🌙']

const formRef = ref<FormInstance>()
const form = reactive<HabitPayload>({ name: '', icon: '🌅', streakDays: 0 })

const rules: FormRules<HabitPayload> = {
  name: [
    { required: true, message: '请输入习惯名称', trigger: 'blur' },
    { max: 80, message: '名称最多 80 个字', trigger: 'blur' },
  ],
}

const reset = () => {
  form.name = props.habit?.name ?? ''
  form.icon = props.habit?.icon ?? '🌅'
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  emit('save', { name: form.name.trim(), icon: form.icon })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    width="440px"
    align-center
    append-to-body
    destroy-on-close
    class="habit-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><Sunny /></el-icon></span>
        <div>
          <strong>{{ habit ? '编辑习惯' : '新增习惯' }}</strong>
          <small>{{ habit ? '调整名称或图标' : '每天一点，慢慢变成习惯' }}</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="习惯名称" prop="name">
        <el-input v-model="form.name" maxlength="80" placeholder="如 早起 / 阅读 30 分钟 / 运动" />
      </el-form-item>

      <el-form-item label="图标">
        <div class="icon-picker">
          <button
            v-for="icon in ICONS"
            :key="icon"
            type="button"
            class="icon-option"
            :class="{ active: form.icon === icon }"
            @click="form.icon = icon"
          >
            {{ icon }}
          </button>
        </div>
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
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 15%, transparent);
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

.icon-picker {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 8px;
  width: 100%;
}

.icon-option {
  height: 40px;
  border: 1px solid var(--border-soft);
  border-radius: 11px;
  background: var(--surface-muted);
  font-size: 19px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.icon-option.active {
  border-color: color-mix(in srgb, var(--primary) 45%, var(--border-color));
  background: var(--primary-soft);
  transform: translateY(-1px);
}

.save-button {
  width: 100%;
  height: 45px;
  border: 0;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
}
</style>

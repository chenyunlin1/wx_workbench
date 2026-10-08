<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import dayjs from 'dayjs'
import type { FormInstance, FormRules } from 'element-plus'
import { Bell, Calendar, Check } from '@element-plus/icons-vue'
import type { Schedule, ScheduleFormPayload, SchedulePriority } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  record?: Schedule | null
  defaultDate?: string
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: ScheduleFormPayload]
}>()

const categoryOptions = ['日程', '会议', '学习', '面试', '提醒', '其他']
const priorityOptions: Array<{ label: string; value: SchedulePriority }> = [
  { label: '高', value: 'high' },
  { label: '中', value: 'medium' },
  { label: '低', value: 'low' },
]
const remindOptions = [
  { label: '提前 5 分钟', value: 5 },
  { label: '提前 15 分钟', value: 15 },
  { label: '提前 1 小时', value: 60 },
  { label: '提前 1 天', value: 1440 },
]

const formRef = ref<FormInstance>()
const form = reactive({
  title: '',
  description: '',
  startTime: dayjs().format('YYYY-MM-DD HH:mm:ss'),
  category: '日程',
  priority: 'medium' as SchedulePriority,
  isRemind: false,
  remindBefore: 15,
})

const rules: FormRules = {
  title: [{ required: true, message: '请输入日程标题', trigger: 'blur' }],
  startTime: [{ required: true, message: '请选择开始时间', trigger: 'change' }],
  category: [{ required: true, message: '请选择分类', trigger: 'change' }],
  priority: [{ required: true, message: '请选择优先级', trigger: 'change' }],
}

const reset = () => {
  const record = props.record
  form.title = record?.title ?? ''
  form.description = record?.description ?? ''
  form.startTime = record?.startTime
    ? dayjs(record.startTime).format('YYYY-MM-DD HH:mm:ss')
    : props.defaultDate
      ? dayjs(props.defaultDate).hour(9).minute(0).second(0).format('YYYY-MM-DD HH:mm:ss')
      : dayjs().format('YYYY-MM-DD HH:mm:ss')
  form.category = record?.category ?? '日程'
  form.priority = record?.priority ?? 'medium'
  form.isRemind = record?.isRemind ?? false
  form.remindBefore = record?.remindBefore ?? 15
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
    description: form.description.trim() || undefined,
    startTime: dayjs(form.startTime).toISOString(),
    category: form.category,
    priority: form.priority,
    isRemind: form.isRemind,
    remindBefore: form.isRemind ? form.remindBefore : undefined,
    completed: props.record?.completed ?? false,
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    :title="record ? '编辑日程' : '新建日程'"
    width="520px"
    align-center
    append-to-body
    destroy-on-close
    class="schedule-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><Calendar /></el-icon></span>
        <div><strong>{{ record ? '编辑日程' : '新建日程' }}</strong><small>把重要安排放进日程，专注于当下</small></div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="标题" prop="title">
        <el-input v-model="form.title" maxlength="160" show-word-limit placeholder="请输入日程标题" />
      </el-form-item>
      <el-form-item label="详情">
        <el-input v-model="form.description" type="textarea" :rows="3" resize="vertical" placeholder="请输入日程详情（可选）" />
      </el-form-item>
      <el-form-item label="开始时间" prop="startTime">
        <el-date-picker v-model="form.startTime" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" format="YYYY/MM/DD HH:mm" placeholder="选择开始时间" style="width: 100%" />
      </el-form-item>
      <div class="form-grid">
        <el-form-item label="分类" prop="category">
          <el-select v-model="form.category" style="width: 100%">
            <el-option v-for="category in categoryOptions" :key="category" :label="category" :value="category" />
          </el-select>
        </el-form-item>
        <el-form-item label="优先级" prop="priority">
          <el-select v-model="form.priority" style="width: 100%">
            <el-option v-for="item in priorityOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
      </div>
      <el-form-item>
        <div class="remind-area">
          <el-checkbox v-model="form.isRemind"><el-icon><Bell /></el-icon>设置提醒</el-checkbox>
          <el-select v-if="form.isRemind" v-model="form.remindBefore" style="width: 170px">
            <el-option v-for="item in remindOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </div>
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button type="primary" size="large" :loading="saving" class="save-button" @click="submit"><el-icon><Check /></el-icon>保存</el-button>
    </template>
  </el-dialog>
</template>

<style scoped lang="scss">
.dialog-heading { display: flex; align-items: center; gap: 11px; }
.dialog-icon { display: grid; width: 39px; height: 39px; place-items: center; border-radius: 12px; color: var(--primary); background: var(--primary-soft); font-size: 19px; }
.dialog-heading strong, .dialog-heading small { display: block; }
.dialog-heading strong { color: var(--text-primary); font-size: 16px; }
.dialog-heading small { margin-top: 3px; color: var(--text-secondary); font-size: 12px; }
.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
.remind-area { display: flex; width: 100%; align-items: center; justify-content: space-between; gap: 12px; }
.remind-area :deep(.el-checkbox__label) { display: inline-flex; align-items: center; gap: 5px; }
.save-button { width: 100%; height: 45px; border: 0; background: linear-gradient(135deg, var(--primary), var(--primary-strong)); }
@media (max-width: 560px) {
  .form-grid { grid-template-columns: 1fr; gap: 0; }
  .remind-area { align-items: flex-start; flex-direction: column; }
  .remind-area :deep(.el-select) { width: 100% !important; }
}
</style>

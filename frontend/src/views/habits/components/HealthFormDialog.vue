<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import dayjs from 'dayjs'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, TrendCharts } from '@element-plus/icons-vue'
import type { Health, HealthPayload } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  record?: Health | null
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: HealthPayload]
}>()

const formRef = ref<FormInstance>()
const form = reactive<HealthPayload>({ weight: 70, recordDate: dayjs().format('YYYY-MM-DD') })

const rules: FormRules<HealthPayload> = {
  weight: [
    { required: true, message: '请输入体重', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        const weight = Number(value)
        if (weight >= 20 && weight <= 300) callback()
        else callback(new Error('体重需在 20 - 300 kg 之间'))
      },
      trigger: 'blur',
    },
  ],
  recordDate: [{ required: true, message: '请选择日期', trigger: 'change' }],
}

const reset = () => {
  form.weight = props.record ? Number(props.record.weight) : 70
  form.recordDate = props.record?.recordDate
    ? dayjs(props.record.recordDate).format('YYYY-MM-DD')
    : dayjs().format('YYYY-MM-DD')
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  emit('save', {
    weight: Number(Number(form.weight).toFixed(2)),
    recordDate: dayjs(form.recordDate).format('YYYY-MM-DD'),
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    width="420px"
    align-center
    append-to-body
    destroy-on-close
    class="health-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><TrendCharts /></el-icon></span>
        <div>
          <strong>{{ record ? '编辑体重记录' : '记录体重' }}</strong>
          <small>坚持记录，才能看清趋势</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="体重（kg）" prop="weight">
        <el-input-number
          v-model="form.weight"
          :min="20"
          :max="300"
          :precision="1"
          :step="0.1"
          controls-position="right"
          style="width: 100%"
        />
      </el-form-item>

      <el-form-item label="日期" prop="recordDate">
        <el-date-picker
          v-model="form.recordDate"
          type="date"
          value-format="YYYY-MM-DD"
          format="YYYY/MM/DD"
          placeholder="选择日期"
          style="width: 100%"
        />
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
  color: var(--secondary);
  background: var(--secondary-soft);
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

.save-button {
  width: 100%;
  height: 45px;
  border: 0;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
}
</style>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import dayjs from 'dayjs'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, TrendCharts, Wallet } from '@element-plus/icons-vue'
import type { Finance, FinanceFormPayload } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  record?: Finance | null
  categories: string[]
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: FinanceFormPayload]
}>()

const formRef = ref<FormInstance>()
const form = reactive<FinanceFormPayload>({
  type: 'expense',
  amount: 0,
  category: '',
  remark: '',
  recordDate: dayjs().format('YYYY-MM-DD HH:mm:ss'),
})

const rules: FormRules<FinanceFormPayload> = {
  type: [{ required: true, message: '请选择收支类型', trigger: 'change' }],
  amount: [
    { required: true, message: '请输入金额', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (Number(value) > 0) callback()
        else callback(new Error('金额必须大于 0'))
      },
      trigger: 'blur',
    },
  ],
  category: [{ required: true, message: '请输入或选择分类', trigger: 'change' }],
  recordDate: [{ required: true, message: '请选择记录时间', trigger: 'change' }],
}

const reset = () => {
  const record = props.record
  form.type = record?.type ?? 'expense'
  form.amount = Number(record?.amount ?? 0)
  form.category = record?.category ?? ''
  form.remark = record?.remark ?? ''
  form.recordDate = record?.recordDate
    ? dayjs(record.recordDate).format('YYYY-MM-DD HH:mm:ss')
    : dayjs().format('YYYY-MM-DD HH:mm:ss')
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  emit('save', {
    type: form.type,
    amount: Number(Number(form.amount).toFixed(2)),
    category: form.category.trim(),
    remark: form.remark?.trim() || undefined,
    recordDate: dayjs(form.recordDate).toISOString(),
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    :title="record ? '编辑记录' : '记一笔'"
    width="480px"
    align-center
    append-to-body
    destroy-on-close
    class="finance-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><Wallet /></el-icon></span>
        <div><strong>{{ record ? '编辑记录' : '记一笔' }}</strong><small>记录每一笔收支，掌控生活节奏</small></div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="类型" prop="type">
        <div class="type-selector">
          <button type="button" class="type-option expense" :class="{ active: form.type === 'expense' }" @click="form.type = 'expense'">
            <el-icon><TrendCharts /></el-icon>支出
          </button>
          <button type="button" class="type-option income" :class="{ active: form.type === 'income' }" @click="form.type = 'income'">
            <el-icon><TrendCharts /></el-icon>收入
          </button>
        </div>
      </el-form-item>

      <el-form-item label="金额" prop="amount">
        <el-input-number v-model="form.amount" :min="0" :precision="2" :step="1" controls-position="right" placeholder="0" style="width: 100%" />
      </el-form-item>

      <el-form-item label="分类" prop="category">
        <el-select v-model="form.category" filterable allow-create default-first-option placeholder="如 餐饮 / 交通 / 薪资" style="width: 100%">
          <el-option v-for="category in props.categories" :key="category" :label="category" :value="category" />
        </el-select>
      </el-form-item>

      <el-form-item label="备注">
        <el-input v-model="form.remark" maxlength="255" placeholder="可选" />
      </el-form-item>

      <el-form-item label="日期" prop="recordDate">
        <el-date-picker v-model="form.recordDate" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" format="YYYY/MM/DD HH:mm" placeholder="选择日期时间" style="width: 100%" />
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
.type-selector { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; width: 100%; }
.type-option { display: flex; height: 44px; align-items: center; justify-content: center; gap: 6px; border: 1px solid var(--border-soft); border-radius: 11px; color: var(--text-regular); background: var(--surface-muted); cursor: pointer; transition: all 0.2s ease; }
.type-option.expense.active { border-color: color-mix(in srgb, var(--danger) 45%, var(--border-color)); color: var(--danger); background: color-mix(in srgb, var(--danger) 12%, var(--surface)); }
.type-option.income.active { border-color: color-mix(in srgb, var(--secondary) 45%, var(--border-color)); color: var(--secondary); background: var(--secondary-soft); }
.save-button { width: 100%; height: 45px; border: 0; background: linear-gradient(135deg, var(--primary), var(--primary-strong)); }
</style>

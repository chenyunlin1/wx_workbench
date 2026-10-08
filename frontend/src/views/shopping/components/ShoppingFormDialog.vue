<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, ShoppingCart } from '@element-plus/icons-vue'
import type { ShoppingItem, ShoppingPayload } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  item?: ShoppingItem | null
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: ShoppingPayload]
}>()

const formRef = ref<FormInstance>()
const form = reactive({
  name: '',
  price: 0,
  status: 'pending' as NonNullable<ShoppingPayload['status']>,
})

const rules: FormRules = {
  name: [
    { required: true, message: '请输入物品名称', trigger: 'blur' },
    { max: 160, message: '名称最多 160 个字', trigger: 'blur' },
  ],
}

const reset = () => {
  form.name = props.item?.name ?? ''
  form.price = Number(props.item?.price ?? 0)
  form.status = props.item?.status ?? 'pending'
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return
  emit('save', {
    name: form.name.trim(),
    price: Number(Number(form.price || 0).toFixed(2)),
    status: form.status,
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    width="430px"
    align-center
    append-to-body
    destroy-on-close
    class="shopping-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><ShoppingCart /></el-icon></span>
        <div>
          <strong>{{ item ? '编辑物品' : '新增物品' }}</strong>
          <small>{{ item ? '修改名称、价格或状态' : '想买的东西先记下来，避免冲动消费' }}</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="物品名称" prop="name">
        <el-input v-model="form.name" maxlength="160" placeholder="如 机械键盘" />
      </el-form-item>

      <el-form-item label="参考价格（元）">
        <el-input-number
          v-model="form.price"
          :min="0"
          :max="1000000"
          :precision="2"
          :step="10"
          controls-position="right"
          style="width: 100%"
        />
      </el-form-item>

      <el-form-item label="状态">
        <el-radio-group v-model="form.status" class="status-group">
          <el-radio-button value="pending">待买</el-radio-button>
          <el-radio-button value="bought">已买</el-radio-button>
        </el-radio-group>
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

.status-group {
  /* el-radio-group 默认按内容收缩，必须显式占满 */
  display: flex;
  width: 100%;
}

.status-group :deep(.el-radio-button) {
  flex: 1;
}

.status-group :deep(.el-radio-button__inner) {
  width: 100%;
}

.save-button {
  width: 100%;
  height: 45px;
  border: 0;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
}
</style>

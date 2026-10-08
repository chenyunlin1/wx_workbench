<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, Collection as CollectionIcon, Picture } from '@element-plus/icons-vue'
import { COLLECTION_TYPE_META, STATUS_ORDER, statusLabel } from '../collection-meta'
import type { CollectionItem, CollectionPayload } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  item?: CollectionItem | null
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: CollectionPayload]
}>()

const formRef = ref<FormInstance>()
const form = reactive<CollectionPayload>({
  type: 'book',
  title: '',
  status: 'wish',
  rating: null,
  year: null,
  coverUrl: '',
  comment: '',
})

const rules: FormRules<CollectionPayload> = {
  title: [
    { required: true, message: '请输入标题', trigger: 'blur' },
    { max: 180, message: '标题最多 180 个字', trigger: 'blur' },
  ],
}

const statusOptions = computed(() =>
  STATUS_ORDER.map((status) => ({ value: status, label: statusLabel(status, form.type) })),
)

const typeLabel = computed(
  () => COLLECTION_TYPE_META.find((meta) => meta.value === form.type)?.label ?? '书籍',
)

const reset = () => {
  const item = props.item
  form.type = item?.type ?? 'book'
  form.title = item?.title ?? ''
  form.status = item?.status ?? 'wish'
  form.rating = item?.rating ?? null
  form.year = item?.year ?? null
  form.coverUrl = item?.coverUrl ?? ''
  form.comment = item?.comment ?? ''
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

const setRating = (value: number) => {
  form.rating = value > 0 ? value : null
}

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  emit('save', {
    type: form.type,
    title: form.title.trim(),
    status: form.status,
    rating: form.rating ?? null,
    year: form.year ?? null,
    coverUrl: form.coverUrl?.trim() || null,
    comment: form.comment?.trim() || null,
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    width="520px"
    align-center
    append-to-body
    destroy-on-close
    class="collection-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon"><el-icon><CollectionIcon /></el-icon></span>
        <div>
          <strong>{{ item ? '编辑收藏' : '新增收藏' }}</strong>
          <small>{{ item ? '更新这条记录的信息' : `记录一本${typeLabel}、一部片或一张专辑` }}</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="标题" prop="title">
        <el-input v-model="form.title" maxlength="180" placeholder="如 置身事内：中国政府与经济发展" />
      </el-form-item>

      <el-form-item label="类型">
        <div class="type-selector">
          <button
            v-for="meta in COLLECTION_TYPE_META"
            :key="meta.value"
            type="button"
            class="type-option"
            :class="[meta.tone, { active: form.type === meta.value }]"
            @click="form.type = meta.value"
          >
            <el-icon><component :is="meta.icon" /></el-icon>
            {{ meta.label }}
          </button>
        </div>
      </el-form-item>

      <el-form-item label="状态">
        <div class="type-selector">
          <button
            v-for="option in statusOptions"
            :key="option.value"
            type="button"
            class="type-option status"
            :class="[option.value, { active: form.status === option.value }]"
            @click="form.status = option.value"
          >
            {{ option.label }}
          </button>
        </div>
      </el-form-item>

      <el-form-item label="评分（1-5）">
        <div class="rating-row">
          <el-rate :model-value="form.rating ?? 0" @update:model-value="setRating" />
          <el-button v-if="form.rating" link size="small" @click="form.rating = null">清除</el-button>
          <span v-else class="rating-hint">未评分</span>
        </div>
      </el-form-item>

      <div class="field-row">
        <el-form-item label="年份">
          <el-input-number
            v-model="form.year"
            :min="0"
            :max="2100"
            :controls="false"
            placeholder="如 2021"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="封面链接">
          <el-input v-model="form.coverUrl" placeholder="https://..." />
        </el-form-item>
      </div>

      <div v-if="form.coverUrl" class="cover-preview">
        <el-image :src="form.coverUrl" fit="cover" class="preview-image">
          <template #error>
            <div class="preview-error"><el-icon><Picture /></el-icon>封面无法加载</div>
          </template>
        </el-image>
      </div>

      <el-form-item label="短评">
        <el-input
          v-model="form.comment"
          type="textarea"
          :rows="3"
          resize="none"
          maxlength="1000"
          show-word-limit
          placeholder="一句话记录你的感受"
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

.type-selector {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 9px;
  width: 100%;
}

.type-option {
  display: flex;
  height: 42px;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 1px solid var(--border-soft);
  border-radius: 11px;
  color: var(--text-regular);
  background: var(--surface-muted);
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.type-option.blue.active {
  border-color: color-mix(in srgb, var(--primary) 45%, var(--border-color));
  color: var(--primary);
  background: var(--primary-soft);
}

.type-option.violet.active {
  border-color: color-mix(in srgb, var(--accent) 45%, var(--border-color));
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 14%, var(--surface));
}

.type-option.green.active {
  border-color: color-mix(in srgb, var(--secondary) 45%, var(--border-color));
  color: var(--secondary);
  background: var(--secondary-soft);
}

.type-option.status.wish.active {
  border-color: color-mix(in srgb, var(--warning) 45%, var(--border-color));
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, var(--surface));
}

.type-option.status.doing.active {
  border-color: color-mix(in srgb, var(--primary) 45%, var(--border-color));
  color: var(--primary);
  background: var(--primary-soft);
}

.type-option.status.done.active {
  border-color: color-mix(in srgb, var(--secondary) 45%, var(--border-color));
  color: var(--secondary);
  background: var(--secondary-soft);
}

.rating-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.rating-hint {
  color: var(--text-secondary);
  font-size: 13px;
}

.field-row {
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 14px;
}

.cover-preview {
  margin: -6px 0 14px;
}

.preview-image {
  width: 88px;
  height: 117px;
  border: 1px solid var(--border-soft);
  border-radius: 10px;
  overflow: hidden;
}

.preview-error {
  display: grid;
  height: 100%;
  place-items: center;
  gap: 4px;
  color: var(--text-secondary);
  background: var(--surface-muted);
  font-size: 12px;
  text-align: center;
}

.save-button {
  width: 100%;
  height: 45px;
  border: 0;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
}

@media (max-width: 560px) {
  .field-row {
    grid-template-columns: 1fr;
  }
}
</style>

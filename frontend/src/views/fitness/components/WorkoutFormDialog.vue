<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import dayjs from 'dayjs'
import type { FormInstance, FormRules } from 'element-plus'
import { Check, Stopwatch } from '@element-plus/icons-vue'
import { INTENSITY_OPTIONS, WORKOUT_TYPES, workoutMeta } from '../workout-meta'
import type { Workout, WorkoutPayload, WorkoutType } from '@/types'

const visible = defineModel<boolean>({ required: true })

const props = defineProps<{
  workout?: Workout | null
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [payload: WorkoutPayload]
}>()

const formRef = ref<FormInstance>()
const form = reactive({
  type: 'running' as WorkoutType,
  title: '',
  duration: 30,
  calories: null as number | null,
  distance: null as number | null,
  intensity: 'medium' as NonNullable<WorkoutPayload['intensity']>,
  workoutDate: dayjs().format('YYYY-MM-DD HH:mm:ss'),
  note: '',
})

const rules: FormRules = {
  type: [{ required: true, message: '请选择训练类型', trigger: 'change' }],
  duration: [
    { required: true, message: '请输入训练时长', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        const minutes = Number(value)
        if (minutes >= 1 && minutes <= 1440) callback()
        else callback(new Error('时长需在 1 - 1440 分钟之间'))
      },
      trigger: 'blur',
    },
  ],
  workoutDate: [{ required: true, message: '请选择训练时间', trigger: 'change' }],
}

const meta = computed(() => workoutMeta(form.type))
const showDistance = computed(() =>
  ['running', 'cycling', 'swimming', 'walking'].includes(form.type),
)

const reset = () => {
  const workout = props.workout
  form.type = workout?.type ?? 'running'
  form.title = workout?.title ?? ''
  form.duration = workout?.duration ?? 30
  form.calories = workout?.calories ?? null
  form.distance = workout?.distance ?? null
  form.intensity = workout?.intensity ?? 'medium'
  form.workoutDate = workout?.workoutDate
    ? dayjs(workout.workoutDate).format('YYYY-MM-DD HH:mm:ss')
    : dayjs().format('YYYY-MM-DD HH:mm:ss')
  form.note = workout?.note ?? ''
  formRef.value?.clearValidate()
}

watch(visible, (opened) => {
  if (opened) reset()
})

watch(
  () => form.type,
  () => {
    // 切换类型后清掉不适用的距离字段
    if (!showDistance.value) form.distance = null
  },
)

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  emit('save', {
    type: form.type,
    title: form.title.trim() || undefined,
    duration: Number(form.duration),
    calories: form.calories === null || Number.isNaN(form.calories) ? null : Number(form.calories),
    distance: form.distance === null || Number.isNaN(form.distance) ? null : Number(form.distance),
    intensity: form.intensity,
    workoutDate: dayjs(form.workoutDate).toISOString(),
    note: form.note.trim() || null,
  })
}
</script>

<template>
  <el-dialog
    v-model="visible"
    width="540px"
    align-center
    append-to-body
    destroy-on-close
    class="workout-form-dialog"
  >
    <template #header>
      <div class="dialog-heading">
        <span class="dialog-icon">{{ meta.emoji }}</span>
        <div>
          <strong>{{ workout ? '编辑训练记录' : '记录训练' }}</strong>
          <small>{{ workout ? '修正这次训练的数据' : '每一次训练都算数' }}</small>
        </div>
      </div>
    </template>

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="训练类型" prop="type">
        <div class="type-picker">
          <button
            v-for="item in WORKOUT_TYPES"
            :key="item.value"
            type="button"
            class="type-option"
            :class="[item.tone, { active: form.type === item.value }]"
            @click="form.type = item.value"
          >
            <span>{{ item.emoji }}</span>
            {{ item.label }}
          </button>
        </div>
      </el-form-item>

      <el-form-item label="训练名称">
        <el-input v-model="form.title" maxlength="120" placeholder="可选，如 晨跑 5 公里 / 上肢力量" />
      </el-form-item>

      <div class="field-row">
        <el-form-item label="时长（分钟）" prop="duration">
          <el-input-number v-model="form.duration" :min="1" :max="1440" controls-position="right" style="width: 100%" />
        </el-form-item>
        <el-form-item label="消耗（千卡）">
          <el-input-number v-model="form.calories" :min="0" :max="20000" :controls="false" placeholder="可选" style="width: 100%" />
        </el-form-item>
      </div>

      <div class="field-row">
        <el-form-item v-if="showDistance" label="距离（公里）">
          <el-input-number v-model="form.distance" :min="0" :max="1000" :precision="2" :step="0.1" :controls="false" placeholder="可选" style="width: 100%" />
        </el-form-item>
        <el-form-item label="训练时间" prop="workoutDate">
          <el-date-picker
            v-model="form.workoutDate"
            type="datetime"
            value-format="YYYY-MM-DD HH:mm:ss"
            format="YYYY/MM/DD HH:mm"
            placeholder="选择时间"
            style="width: 100%"
          />
        </el-form-item>
      </div>

      <el-form-item label="强度">
        <el-radio-group v-model="form.intensity" class="intensity-group">
          <el-radio-button v-for="item in INTENSITY_OPTIONS" :key="item.value" :value="item.value">
            {{ item.label }}
          </el-radio-button>
        </el-radio-group>
      </el-form-item>

      <el-form-item label="备注">
        <el-input
          v-model="form.note"
          type="textarea"
          :rows="3"
          resize="none"
          maxlength="500"
          show-word-limit
          placeholder="配速、组数、身体感受……"
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
  background: var(--primary-soft);
  font-size: 20px;
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

.type-picker {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  width: 100%;
}

.type-option {
  display: flex;
  height: 52px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  border: 1px solid var(--border-soft);
  border-radius: 11px;
  color: var(--text-regular);
  background: var(--surface-muted);
  font-size: 13px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.type-option span {
  font-size: 18px;
  /* emoji 的行盒自带一截下方空白，收掉才能和文字贴近、整体居中 */
  line-height: 1;
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

.type-option.teal.active {
  border-color: color-mix(in srgb, #22d3ee 45%, var(--border-color));
  color: #0891b2;
  background: color-mix(in srgb, #22d3ee 14%, var(--surface));
}

.type-option.rose.active {
  border-color: color-mix(in srgb, #fb7185 45%, var(--border-color));
  color: #e11d48;
  background: color-mix(in srgb, #fb7185 14%, var(--surface));
}

.type-option.orange.active {
  border-color: color-mix(in srgb, var(--warning) 45%, var(--border-color));
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, var(--surface));
}

.field-row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.intensity-group {
  /* el-radio-group 默认按内容收缩，必须显式占满，否则子项的百分比宽度算不准 */
  display: flex;
  width: 100%;
}

.intensity-group :deep(.el-radio-button) {
  flex: 1;
}

.intensity-group :deep(.el-radio-button__inner) {
  width: 100%;
}

.save-button {
  width: 100%;
  height: 45px;
  border: 0;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
}

@media (max-width: 560px) {
  .type-picker {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .field-row {
    grid-template-columns: 1fr;
  }
}
</style>

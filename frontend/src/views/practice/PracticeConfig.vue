<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { EditPen, Postcard } from '@element-plus/icons-vue'
import { generatePractice, getPracticeCount, getPracticeTags } from '@/api/practice'
import { usePracticeStore } from '@/stores/practice'
import type { PracticeMode } from '@/types'

const router = useRouter()
const practiceStore = usePracticeStore()
const mode = ref<PracticeMode>('flashcard')
const range = ref('all')
const count = ref(10)
const noteCount = ref(0)
const tags = ref<string[]>([])
const counting = ref(false)
const starting = ref(false)
const countOptions = [5, 10, 20, 50]

const rangeOptions = computed(() => [
  { label: '全部笔记', value: 'all' },
  { label: '已学习笔记', value: 'learned' },
  { label: '未学习笔记', value: 'unlearned' },
  ...tags.value.map((tag) => ({ label: tag, value: tag })),
])

const loadTags = async () => { tags.value = await getPracticeTags() }

const loadCount = async () => {
  counting.value = true
  try { noteCount.value = await getPracticeCount(range.value) }
  finally { counting.value = false }
}

watch(range, loadCount)

const startPractice = async () => {
  if (!noteCount.value) {
    ElMessage.warning('当前范围内没有可用笔记，请先补充知识库')
    return
  }
  starting.value = true
  try {
    practiceStore.startSession({ mode: mode.value, range: range.value, count: count.value })
    const questions = await generatePractice({ mode: mode.value, range: range.value, count: count.value })
    if (!questions.length) {
      ElMessage.warning('没有生成可用题目，请调整练习范围')
      return
    }
    practiceStore.setQuestions(questions)
    await router.push({ name: 'practice-session', query: { mode: mode.value, range: range.value, count: String(count.value) } })
  } finally {
    starting.value = false
  }
}

onMounted(async () => { await Promise.all([loadTags(), loadCount()]) })
</script>
<template>
  <section class="practice-config">
    <header class="config-heading">
      <p>KNOWLEDGE PRACTICE</p>
      <h2>知识练习</h2>
      <span>基于知识库笔记生成练习，边学边测，巩固记忆（成绩仅本次会话内展示，不落库）</span>
    </header>

    <el-card class="config-card" shadow="never">
      <template #header>
        <div class="card-title"><strong>练习模式</strong><span>选择适合你的记忆方式</span></div>
      </template>
      <div class="mode-grid">
        <button class="mode-option" :class="{ active: mode === 'flashcard' }" @click="mode = 'flashcard'">
          <span class="mode-icon flash"><el-icon><Postcard /></el-icon></span>
          <div><strong>闪卡自测</strong><p>看标题回忆内容，翻卡对照，自评掌握程度</p></div>
          <span class="mode-check" :class="{ checked: mode === 'flashcard' }" />
        </button>
        <button class="mode-option" :class="{ active: mode === 'fillblank' }" @click="mode = 'fillblank'">
          <span class="mode-icon blank"><el-icon><EditPen /></el-icon></span>
          <div><strong>关键词填空</strong><p>挖空笔记中的关键概念，四选一还原</p></div>
          <span class="mode-check" :class="{ checked: mode === 'fillblank' }" />
        </button>
      </div>
    </el-card>

    <el-card class="config-card parameters-card" shadow="never">
      <div class="parameter-grid">
        <div class="parameter-field">
          <label>练习范围</label>
          <el-select v-model="range" placeholder="选择练习范围">
            <el-option v-for="option in rangeOptions" :key="option.value" :label="option.label" :value="option.value" />
          </el-select>
        </div>
        <div class="parameter-field">
          <label>题目数量</label>
          <el-select v-model="count" placeholder="选择题目数量">
            <el-option v-for="item in countOptions" :key="item" :label="`${item} 题`" :value="item" />
          </el-select>
        </div>
      </div>
      <p class="range-count" :class="{ loading: counting }">当前范围共 <strong>{{ noteCount }}</strong> 篇笔记</p>
      <el-button type="primary" size="large" class="start-button" :loading="starting" :disabled="!noteCount" @click="startPractice">开始练习</el-button>
    </el-card>

    <el-card class="config-card instructions-card" shadow="never">
      <template #header><div class="card-title"><strong>练习说明</strong></div></template>
      <ul>
        <li><b>闪卡自测</b>：先看标题与标签主动回忆，翻卡核对内容后自评「记得 / 模糊 / 忘了」，评「忘了」的笔记会进入待巩固清单。</li>
        <li><b>关键词填空</b>：系统从笔记的标签与技术栈中挑选关键概念挖空（无标签时自动从内容提取），在近似词干扰下四选一作答。</li>
        <li>练习数据完全来源于你的知识库笔记，练习过程不写入任何数据，可放心反复演练。</li>
      </ul>
    </el-card>
  </section>
</template>

<style scoped lang="scss">
.practice-config { display: grid; gap: 18px; max-width: 1040px; margin: 0 auto; animation: practice-in 0.35s ease both; }
@keyframes practice-in { from { opacity: 0; transform: translateY(7px); } }
.config-heading p { margin: 0 0 6px; color: var(--primary); font-size: 12px; font-weight: 800; letter-spacing: 0.18em; }
.config-heading h2 { margin: 0; color: var(--text-primary); font-size: 30px; letter-spacing: -0.04em; }
.config-heading span { display: block; margin-top: 8px; color: var(--text-secondary); font-size: 13px; }
.config-card { border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-sm); }
.config-card :deep(.el-card__header) { border-bottom-color: var(--border-soft); }
.card-title { display: flex; align-items: baseline; gap: 10px; }
.card-title strong { color: var(--text-primary); font-size: 16px; }
.card-title span { color: var(--text-secondary); font-size: 12px; }
.mode-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
.mode-option { position: relative; display: flex; min-height: 116px; align-items: center; gap: 15px; padding: 20px; border: 1.5px solid var(--border-soft); border-radius: 15px; color: inherit; background: var(--surface-muted); text-align: left; cursor: pointer; transition: all 0.2s ease; }
.mode-option:hover { border-color: color-mix(in srgb, var(--primary) 32%, var(--border-color)); transform: translateY(-2px); }
.mode-option.active { border-color: var(--primary); background: linear-gradient(135deg, var(--primary-soft), color-mix(in srgb, var(--primary-soft) 35%, var(--surface))); box-shadow: 0 10px 25px color-mix(in srgb, var(--primary) 12%, transparent); }
.mode-icon { display: grid; width: 48px; height: 48px; flex: none; place-items: center; border-radius: 14px; font-size: 24px; }
.mode-icon.flash { color: var(--primary); background: var(--primary-soft); }
.mode-icon.blank { color: var(--accent); background: color-mix(in srgb, var(--accent) 14%, transparent); }
.mode-option strong { color: var(--text-primary); font-size: 16px; }
.mode-option p { margin: 7px 0 0; color: var(--text-secondary); font-size: 12px; line-height: 1.7; }
.mode-check { position: absolute; top: 13px; right: 13px; width: 12px; height: 12px; border: 1.5px solid var(--border-color); border-radius: 50%; }
.mode-check.checked { border: 3px solid var(--surface); background: var(--primary); box-shadow: 0 0 0 1px var(--primary); }
.parameter-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 17px; }
.parameter-field label { display: block; margin-bottom: 8px; color: var(--text-regular); font-size: 13px; font-weight: 700; }
.parameter-field :deep(.el-select) { width: 100%; }
.range-count { margin: 15px 0 20px; color: var(--text-secondary); font-size: 13px; }
.range-count strong { color: var(--primary); font-size: 17px; }
.start-button { width: 100%; height: 48px; border: 0; font-weight: 700; letter-spacing: 0.06em; background: linear-gradient(135deg, var(--primary), var(--primary-strong)); box-shadow: 0 10px 24px color-mix(in srgb, var(--primary) 24%, transparent); }
.instructions-card ul { padding-left: 20px; margin: 0; color: var(--text-regular); font-size: 13px; line-height: 2; }
.instructions-card li + li { margin-top: 5px; }
.instructions-card b { color: var(--text-primary); }
@media (max-width: 720px) {
  .mode-grid, .parameter-grid { grid-template-columns: 1fr; }
  .mode-option { min-height: 102px; padding: 16px; }
  .config-heading h2 { font-size: 24px; }
}
</style>

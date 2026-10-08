<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, Check, Clock, Refresh, WarningFilled } from '@element-plus/icons-vue'
import { usePracticeStore } from '@/stores/practice'

const router = useRouter()
const practiceStore = usePracticeStore()
const summary = computed(() => practiceStore.summary)
const forgottenQuestions = computed(() => practiceStore.forgottenQuestions)
const hasResult = computed(() => practiceStore.questions.length > 0)
const durationText = computed(() => {
  const seconds = summary.value.duration
  return seconds < 60 ? seconds + ' 秒' : Math.floor(seconds / 60) + ' 分 ' + (seconds % 60) + ' 秒'
})

const goConfig = async () => {
  practiceStore.reset()
  await router.replace({ name: 'practice' })
}

const retry = async () => {
  const config = { mode: practiceStore.mode, range: practiceStore.range, count: practiceStore.count }
  practiceStore.restart()
  await router.replace({
    name: 'practice-session',
    query: { mode: config.mode, range: config.range, count: String(config.count) },
  })
}

const openKnowledge = async (title: string) => {
  practiceStore.reset()
  await router.push({ name: 'learning', query: { keyword: title } })
}
</script>

<template>
  <section class="practice-result">
    <header class="result-heading">
      <p>PRACTICE COMPLETE</p>
      <h2>练习完成</h2>
      <span>本次成绩仅保留在当前会话中，不会写入数据库</span>
    </header>

    <template v-if="hasResult">
      <el-card class="result-card summary-card" shadow="never">
        <div class="result-hero">
          <div class="result-ring" :style="{ '--result': String(summary.total ? summary.remembered / summary.total * 360 : 0) + 'deg' }">
            <div><strong>{{ summary.total ? Math.round(summary.remembered / summary.total * 100) : 0 }}%</strong><span>记忆掌握度</span></div>
          </div>
          <div class="result-copy">
            <h3>完成 {{ summary.total }} 道练习</h3>
            <p>记得 {{ summary.remembered }} 题，模糊 {{ summary.fuzzy }} 题，忘啦 {{ summary.forgotten }} 题。</p>
            <span><el-icon><Clock /></el-icon>总用时 {{ durationText }}</span>
          </div>
        </div>
      </el-card>

      <div class="stat-grid">
        <div class="stat-item total"><span>总题数</span><strong>{{ summary.total }}</strong></div>
        <div class="stat-item remembered"><span>记得</span><strong>{{ summary.remembered }}</strong></div>
        <div class="stat-item fuzzy"><span>模糊</span><strong>{{ summary.fuzzy }}</strong></div>
        <div class="stat-item forgotten"><span>忘啦</span><strong>{{ summary.forgotten }}</strong></div>
      </div>

      <el-card v-if="practiceStore.mode === 'flashcard' && forgottenQuestions.length" class="result-card consolidate-card" shadow="never">
        <template #header>
          <div class="consolidate-title"><el-icon><WarningFilled /></el-icon><strong>待巩固清单</strong><span>{{ forgottenQuestions.length }} 条笔记</span></div>
        </template>
        <div class="consolidate-list">
          <button v-for="question in forgottenQuestions" :key="question.id" @click="openKnowledge(question.title)">
            <el-icon><WarningFilled /></el-icon>
            <span>{{ question.title }}</span>
            <el-icon><ArrowLeft class="arrow" /></el-icon>
          </button>
        </div>
      </el-card>

      <div class="result-actions">
        <el-button size="large" @click="retry"><el-icon><Refresh /></el-icon>重新练习</el-button>
        <el-button type="primary" size="large" @click="goConfig"><el-icon><ArrowLeft /></el-icon>返回配置页</el-button>
      </div>
    </template>

    <el-empty v-else description="没有可展示的练习结果">
      <el-button type="primary" @click="goConfig">返回配置页</el-button>
    </el-empty>
  </section>
</template>

<style scoped lang="scss">
.practice-result { display: grid; gap: 18px; max-width: 980px; margin: 0 auto; animation: result-in 0.35s ease both; }
@keyframes result-in { from { opacity: 0; transform: translateY(7px); } }
.result-heading p { margin: 0 0 6px; color: var(--secondary); font-size: 12px; font-weight: 800; letter-spacing: 0.18em; }
.result-heading h2 { margin: 0; color: var(--text-primary); font-size: 30px; letter-spacing: -0.04em; }
.result-heading span { display: block; margin-top: 8px; color: var(--text-secondary); font-size: 13px; }
.result-card { border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-sm); }
.result-hero { display: flex; align-items: center; gap: 24px; }
.result-ring { position: relative; display: grid; width: 112px; height: 112px; flex: none; place-items: center; border-radius: 50%; background: conic-gradient(var(--secondary) var(--result), var(--border-soft) 0); }
.result-ring::before { position: absolute; width: 86px; height: 86px; border-radius: 50%; background: var(--surface); content: ''; }
.result-ring > div { position: relative; z-index: 1; text-align: center; }
.result-ring strong, .result-ring span { display: block; }
.result-ring strong { color: var(--text-primary); font-size: 24px; }
.result-ring span { margin-top: 3px; color: var(--text-secondary); font-size: 12px; }
.result-copy h3 { margin: 0; color: var(--text-primary); font-size: 22px; }
.result-copy p { margin: 9px 0 12px; color: var(--text-secondary); font-size: 13px; }
.result-copy > span { display: inline-flex; align-items: center; gap: 5px; padding: 5px 8px; border-radius: 8px; color: var(--primary); background: var(--primary-soft); font-size: 12px; }
.stat-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
.stat-item { padding: 17px; border: 1px solid var(--border-soft); border-radius: 14px; background: var(--surface-raised); box-shadow: var(--shadow-xs); }
.stat-item span, .stat-item strong { display: block; }
.stat-item span { color: var(--text-secondary); font-size: 12px; }
.stat-item strong { margin-top: 7px; font-size: 29px; }
.stat-item.total strong { color: var(--primary); }
.stat-item.remembered strong { color: var(--secondary); }
.stat-item.fuzzy strong { color: var(--warning); }
.stat-item.forgotten strong { color: var(--danger); }
.consolidate-title { display: flex; align-items: center; gap: 7px; color: var(--warning); }
.consolidate-title strong { color: var(--text-primary); font-size: 15px; }
.consolidate-title span { margin-left: auto; color: var(--text-secondary); font-size: 12px; }
.consolidate-list { display: grid; gap: 9px; }
.consolidate-list button { display: flex; width: 100%; align-items: center; gap: 10px; padding: 12px 13px; border: 1px solid var(--border-soft); border-radius: 11px; color: var(--text-regular); background: var(--surface-muted); text-align: left; cursor: pointer; transition: all 0.2s ease; }
.consolidate-list button:hover { border-color: var(--warning); color: var(--warning); background: color-mix(in srgb, var(--warning) 9%, var(--surface)); }
.consolidate-list button > span { flex: 1; font-size: 13px; }
.consolidate-list .arrow { transform: rotate(180deg); }
.result-actions { display: flex; justify-content: center; gap: 12px; padding-top: 4px; }
@media (max-width: 720px) {
  .result-hero { align-items: flex-start; flex-direction: column; }
  .stat-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .result-actions { flex-direction: column; }
  .result-actions :deep(.el-button) { width: 100%; margin-left: 0; }
}
</style>

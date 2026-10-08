<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Clock, Close, EditPen, Postcard } from '@element-plus/icons-vue'
import { generatePractice } from '@/api/practice'
import { usePracticeStore } from '@/stores/practice'
import type { PracticeMode, PracticeQuestion } from '@/types'

const route = useRoute()
const router = useRouter()
const practiceStore = usePracticeStore()
const elapsedSeconds = ref(0)
const flipped = ref(false)
const answering = ref(false)
const selectedAnswer = ref('')
let timer: number | undefined

const currentQuestion = computed(() => practiceStore.currentQuestion)
const flashcardQuestion = computed(() => currentQuestion.value?.type === 'flashcard' ? currentQuestion.value : null)
const fillblankQuestion = computed(() => currentQuestion.value?.type === 'fillblank' ? currentQuestion.value : null)
const total = computed(() => practiceStore.questions.length)
const currentNumber = computed(() => Math.min(practiceStore.currentIndex + 1, total.value))
const progress = computed(() => total.value ? Math.round((practiceStore.currentIndex / total.value) * 100) : 0)

const parseQuery = () => ({
  mode: (route.query.mode === 'fillblank' ? 'fillblank' : 'flashcard') as PracticeMode,
  range: typeof route.query.range === 'string' ? route.query.range : 'all',
  count: Math.max(1, Number(route.query.count) || 10),
})

const ensureQuestions = async () => {
  const config = parseQuery()
  const configChanged = practiceStore.mode !== config.mode || practiceStore.range !== config.range || practiceStore.count !== config.count
  if (configChanged || !practiceStore.questions.length) {
    practiceStore.startSession(config)
    const questions = await generatePractice(config)
    if (!questions.length) {
      ElMessage.warning('当前范围没有可用题目')
      await router.replace({ name: 'practice' })
      return
    }
    practiceStore.setQuestions(questions)
  }
  elapsedSeconds.value = Math.max(0, Math.floor((Date.now() - practiceStore.startTime) / 1000))
}

const finishSession = async () => {
  await router.push({ name: 'practice-result' })
}

const answerFlashcard = async (result: 'remembered' | 'fuzzy' | 'forgotten') => {
  if (!flipped.value) {
    ElMessage.info('先翻卡核对答案，再进行自评')
    return
  }
  practiceStore.recordAnswer(result)
  if (practiceStore.isFinished) await finishSession()
}

const optionClass = (option: string) => {
  if (!selectedAnswer.value || !fillblankQuestion.value) return ''
  if (option === fillblankQuestion.value.correctAnswer) return 'correct'
  if (option === selectedAnswer.value) return 'wrong'
  return ''
}

const answerFillblank = async (option: string) => {
  const question = fillblankQuestion.value
  if (!question || answering.value) return
  answering.value = true
  selectedAnswer.value = option
  const correct = option === question.correctAnswer
  practiceStore.recordAnswer(correct ? 'remembered' : 'forgotten', {
    selectedAnswer: option,
    correctAnswer: question.correctAnswer,
  })
  window.setTimeout(async () => {
    answering.value = false
    if (practiceStore.isFinished) await finishSession()
  }, 650)
}

const exitPractice = async () => {
  await ElMessageBox.confirm('退出后本次答题进度将不会保留，确定退出吗？', '退出练习', {
    type: 'warning',
    confirmButtonText: '退出',
    cancelButtonText: '继续练习',
  })
  practiceStore.reset()
  await router.replace({ name: 'practice' })
}

watch(() => practiceStore.currentIndex, () => {
  flipped.value = false
  selectedAnswer.value = ''
})

onMounted(async () => {
  await ensureQuestions()
  timer = window.setInterval(() => {
    if (practiceStore.startTime) elapsedSeconds.value = Math.floor((Date.now() - practiceStore.startTime) / 1000)
  }, 1000)
})

onUnmounted(() => {
  if (timer) window.clearInterval(timer)
})

onBeforeRouteLeave((_to, _from, next) => {
  if (practiceStore.isFinished || !practiceStore.questions.length) next()
  else next()
})
</script>

<template>
  <section class="practice-session">
    <header class="session-status">
      <div class="status-left">
        <span class="session-icon"><el-icon><Postcard v-if="practiceStore.mode === 'flashcard'" /><EditPen v-else /></el-icon></span>
        <div><strong>第 {{ currentNumber }} / {{ total }} 题</strong><small>{{ practiceStore.mode === 'flashcard' ? '闪卡自测' : '关键词填空' }}</small></div>
      </div>
      <div class="status-right">
        <span class="timer"><el-icon><Clock /></el-icon>已用时 {{ elapsedSeconds }} 秒</span>
        <el-button plain @click="exitPractice"><el-icon><Close /></el-icon>退出练习</el-button>
      </div>
    </header>

    <el-progress :percentage="progress" :show-text="false" :stroke-width="6" class="practice-progress" />

    <main v-if="currentQuestion" class="question-stage">
      <button class="question-card" :class="{ flipped: flipped, 'not-flipped': practiceStore.mode === 'flashcard' && !flipped }" @click="practiceStore.mode === 'flashcard' && (flipped = !flipped)">
        <span class="question-type">{{ currentQuestion.type === 'flashcard' ? '笔记' : '关键词填空' }}</span>
        <div class="question-content">
          <template v-if="flashcardQuestion">
            <h3>{{ flashcardQuestion.title }}</h3>
            <div v-if="flipped" class="answer-content">{{ flashcardQuestion.content }}</div>
            <p v-else class="recall-hint">先主动回忆这篇笔记的核心内容</p>
          </template>
          <template v-else-if="fillblankQuestion">
            <h3>{{ fillblankQuestion.title }}</h3>
          </template>
        </div>
        <div class="question-tags">
          <el-tag v-for="tag in currentQuestion.tags" :key="tag" effect="light" round>{{ tag }}</el-tag>
        </div>
        <span v-if="flashcardQuestion && !flipped" class="click-tip">点击卡片查看答案</span>
      </button>

      <div v-if="flashcardQuestion && flipped" class="assessment-area">
        <div class="assessment-buttons">
          <el-button class="assessment-button forgotten" @click="answerFlashcard('forgotten')">忘啦</el-button>
          <el-button class="assessment-button fuzzy" @click="answerFlashcard('fuzzy')">模糊</el-button>
          <el-button class="assessment-button remembered" @click="answerFlashcard('remembered')">记得</el-button>
        </div>
        <p>先在心理回忆这章笔记的内容，再翻卡核对</p>
      </div>

      <div v-if="fillblankQuestion" class="options-area">
        <button v-for="(option, index) in fillblankQuestion.options" :key="option" class="option-button" :class="optionClass(option)" :disabled="answering" @click="answerFillblank(option)">
          <span class="option-letter">{{ String.fromCharCode(65 + index) }}</span>
          <span>{{ option }}</span>
        </button>
      </div>
    </main>

    <el-empty v-else description="没有可练习的题目">
      <el-button type="primary" @click="router.replace({ name: 'practice' })">返回配置页</el-button>
    </el-empty>
  </section>
</template>

<style scoped lang="scss">
.practice-session { display: grid; gap: 18px; max-width: 980px; margin: 0 auto; }
.session-status { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.status-left, .status-right, .timer { display: flex; align-items: center; }
.status-left { gap: 11px; }
.session-icon { display: grid; width: 42px; height: 42px; place-items: center; border-radius: 13px; color: var(--primary); background: var(--primary-soft); font-size: 20px; }
.status-left strong, .status-left small { display: block; }
.status-left strong { color: var(--text-primary); font-size: 16px; }
.status-left small { margin-top: 3px; color: var(--text-secondary); font-size: 12px; }
.status-right { gap: 10px; }
.timer { gap: 5px; padding: 8px 11px; border: 1px solid var(--border-soft); border-radius: 9px; color: var(--text-regular); background: var(--surface-raised); font-size: 12px; }
.practice-progress :deep(.el-progress-bar__outer) { background: var(--border-soft); }
.practice-progress :deep(.el-progress-bar__inner) { background: var(--primary); }
.question-stage { display: grid; gap: 17px; }
.question-card { position: relative; display: flex; min-height: 390px; flex-direction: column; justify-content: space-between; padding: 30px; border: 1px solid var(--border-soft); border-radius: 22px; color: inherit; background: radial-gradient(circle at 82% 12%, var(--primary-soft), transparent 15rem), var(--surface-raised); box-shadow: var(--shadow-md); cursor: default; transition: transform 0.25s ease, box-shadow 0.25s ease; }
.question-card.not-flipped { cursor: pointer; }
.question-card.not-flipped:hover { transform: translateY(-3px); box-shadow: 0 22px 52px color-mix(in srgb, var(--primary) 14%, transparent); }
.question-card.flipped { background: radial-gradient(circle at 82% 12%, var(--secondary-soft), transparent 15rem), var(--surface-raised); }
.question-type { align-self: flex-start; padding: 5px 9px; border-radius: 8px; color: var(--primary); background: var(--primary-soft); font-size: 12px; }
.question-content { display: grid; min-height: 210px; place-items: center; text-align: center; }
.question-content h3 { max-width: 720px; margin: 0; color: var(--text-primary); font-size: clamp(22px, 3.2vw, 34px); line-height: 1.55; letter-spacing: -0.035em; }
.answer-content { max-width: 720px; padding: 20px; border: 1px solid var(--border-soft); border-radius: 14px; color: var(--text-regular); background: var(--surface-muted); font-size: 16px; line-height: 1.9; white-space: pre-wrap; }
.recall-hint { margin: 16px 0 0; color: var(--text-secondary); font-size: 13px; }
.question-tags { display: flex; flex-wrap: wrap; justify-content: center; gap: 7px; }
.question-tags :deep(.el-tag) { border-color: color-mix(in srgb, var(--primary) 18%, var(--border-color)); color: var(--primary); background: color-mix(in srgb, var(--primary-soft) 75%, transparent); }
.click-tip { position: absolute; bottom: -27px; left: 50%; color: var(--text-secondary); font-size: 12px; transform: translateX(-50%); white-space: nowrap; }
.assessment-area { display: grid; gap: 11px; padding-top: 17px; }
.assessment-buttons { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
.assessment-button { height: 60px; border: 0; border-radius: 13px; font-size: 16px; font-weight: 750; }
.assessment-button.forgotten { color: #dc2626; background: #fee2e2; }
.assessment-button.fuzzy { color: #d97706; background: #fef3c7; }
.assessment-button.remembered { color: #059669; background: #d1fae5; }
.assessment-area p { margin: 0; color: var(--text-secondary); font-size: 12px; text-align: center; }
.options-area { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
.option-button { display: flex; min-height: 64px; align-items: center; gap: 12px; padding: 13px 16px; border: 1px solid var(--border-soft); border-radius: 13px; color: var(--text-regular); background: var(--surface-raised); text-align: left; cursor: pointer; transition: all 0.2s ease; }
.option-button:hover:not(:disabled) { border-color: var(--primary); color: var(--primary); background: var(--primary-soft); transform: translateY(-2px); }
.option-button.correct { border-color: var(--secondary); color: var(--secondary); background: var(--secondary-soft); }
.option-button.wrong { border-color: var(--danger); color: var(--danger); background: color-mix(in srgb, var(--danger) 10%, var(--surface)); }
.option-letter { display: grid; width: 30px; height: 30px; flex: none; place-items: center; border-radius: 9px; color: var(--primary); background: var(--primary-soft); font-size: 13px; font-weight: 800; }
.option-button.correct .option-letter { color: #fff; background: var(--secondary); }
.option-button.wrong .option-letter { color: #fff; background: var(--danger); }
@media (max-width: 720px) {
  .session-status { align-items: flex-start; flex-direction: column; }
  .status-right { width: 100%; justify-content: space-between; }
  .question-card { min-height: 360px; padding: 22px 17px; }
  .assessment-buttons, .options-area { grid-template-columns: 1fr; }
}
</style>

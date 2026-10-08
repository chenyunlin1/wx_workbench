import { defineStore } from 'pinia'
import type { PracticeAnswer, PracticeAnswerResult, PracticeMode, PracticeQuestion, PracticeResultSummary } from '@/types'

interface PracticeSessionConfig { mode: PracticeMode; range: string; count: number }

export const usePracticeStore = defineStore('practice', {
  state: () => ({
    mode: 'flashcard' as PracticeMode,
    range: 'all',
    count: 10,
    questions: [] as PracticeQuestion[],
    answers: [] as PracticeAnswer[],
    currentIndex: 0,
    startTime: 0,
  }),
  getters: {
    currentQuestion(state): PracticeQuestion | null { return state.questions[state.currentIndex] ?? null },
    isFinished(state) { return state.questions.length > 0 && state.currentIndex >= state.questions.length },
    summary(state): PracticeResultSummary {
      return {
        total: state.questions.length,
        remembered: state.answers.filter((answer) => answer.result === 'remembered').length,
        fuzzy: state.answers.filter((answer) => answer.result === 'fuzzy').length,
        forgotten: state.answers.filter((answer) => answer.result === 'forgotten').length,
        duration: state.startTime ? Math.max(0, Math.floor((Date.now() - state.startTime) / 1000)) : 0,
      }
    },
    forgottenQuestions(state) {
      const forgottenIds = new Set(state.answers.filter((answer) => answer.result === 'forgotten').map((answer) => answer.questionId))
      return state.questions.filter((question) => forgottenIds.has(question.id))
    },
  },
  actions: {
    startSession(config: PracticeSessionConfig) {
      this.mode = config.mode
      this.range = config.range
      this.count = config.count
      this.questions = []
      this.answers = []
      this.currentIndex = 0
      this.startTime = Date.now()
    },
    setQuestions(questions: PracticeQuestion[]) {
      this.questions = questions
      this.currentIndex = 0
      if (!this.startTime) this.startTime = Date.now()
    },
    recordAnswer(result: PracticeAnswerResult, extra: Partial<PracticeAnswer> = {}) {
      const question = this.currentQuestion
      if (!question) return
      this.answers.push({ questionId: question.id, questionType: this.mode, title: question.title, tags: [...question.tags], result, ...extra })
      this.next()
    },
    next() { this.currentIndex += 1 },
    restart() { this.questions = []; this.answers = []; this.currentIndex = 0; this.startTime = Date.now() },
    reset() { this.mode = 'flashcard'; this.range = 'all'; this.count = 10; this.questions = []; this.answers = []; this.currentIndex = 0; this.startTime = 0 },
  },
})
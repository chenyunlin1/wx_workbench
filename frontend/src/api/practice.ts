import { request } from './index'
import type { PracticeMode, PracticeQuestion, PracticeResultSummary } from '@/types'

export const getPracticeCount = (range: string) =>
  request<number>({ url: '/practice/count', method: 'GET', params: { range } })

export const getPracticeTags = () =>
  request<string[]>({ url: '/practice/tags', method: 'GET' })

export const generatePractice = (params: { mode: PracticeMode; range: string; count: number }) =>
  request<PracticeQuestion[]>({ url: '/practice/generate', method: 'GET', params })

export const submitPracticeResult = (data: PracticeResultSummary & { mode: PracticeMode }) =>
  request<{ accepted: boolean; persisted: boolean }>({ url: '/practice/result', method: 'POST', data })
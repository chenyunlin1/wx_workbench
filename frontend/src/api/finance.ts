import { request } from './index'
import type { Finance, FinanceFormPayload, FinanceListResult, FinanceQuery, FinanceSummary } from '@/types'

export const listFinance = (params: FinanceQuery) =>
  request<FinanceListResult>({ url: '/finance', method: 'GET', params })

export const getFinanceSummary = (month?: string) =>
  request<FinanceSummary>({ url: '/finance/summary', method: 'GET', params: { month } })

export const getFinanceCategories = () =>
  request<string[]>({ url: '/finance/categories', method: 'GET' })

export const createFinance = (data: FinanceFormPayload) =>
  request<Finance>({ url: '/finance', method: 'POST', data })

export const updateFinance = (id: number, data: Partial<FinanceFormPayload>) =>
  request<Finance>({ url: `/finance/${id}`, method: 'PATCH', data })

export const deleteFinance = (id: number) =>
  request<{ success: boolean }>({ url: `/finance/${id}`, method: 'DELETE' })

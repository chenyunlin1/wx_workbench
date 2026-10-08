import { request } from './index'
import type { DashboardSummary } from '@/types'

export const getDashboardSummary = () =>
  request<DashboardSummary>({
    url: '/dashboard/summary',
    method: 'GET',
  })
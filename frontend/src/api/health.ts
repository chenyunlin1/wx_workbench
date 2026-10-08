import { request } from './index'
import type { Health, HealthPayload, HealthTrend } from '@/types'

export const listHealth = () =>
  request<Health[]>({
    url: '/health/records',
    method: 'GET',
  })

export const getHealthTrend = (limit = 7) =>
  request<HealthTrend>({
    url: '/health/trend',
    method: 'GET',
    params: { limit },
  })

export const createHealth = (data: HealthPayload) =>
  request<Health>({
    url: '/health',
    method: 'POST',
    data,
  })

export const updateHealth = (id: number, data: Partial<HealthPayload>) =>
  request<Health>({
    url: `/health/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteHealth = (id: number) =>
  request<{ success: boolean }>({
    url: `/health/${id}`,
    method: 'DELETE',
  })

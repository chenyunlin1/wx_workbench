import { request } from './index'
import type { Schedule, ScheduleFormPayload } from '@/types'

export const listSchedules = (params: { start?: string; end?: string } = {}) =>
  request<Schedule[]>({ url: '/schedule', method: 'GET', params })

export const getScheduleDetail = (id: number) =>
  request<Schedule>({ url: `/schedule/${id}`, method: 'GET' })

export const createSchedule = (data: ScheduleFormPayload) =>
  request<Schedule>({ url: '/schedule', method: 'POST', data })

export const updateSchedule = (id: number, data: Partial<ScheduleFormPayload>) =>
  request<Schedule>({ url: `/schedule/${id}`, method: 'PATCH', data })

export const deleteSchedule = (id: number) =>
  request<{ success: boolean }>({ url: `/schedule/${id}`, method: 'DELETE' })

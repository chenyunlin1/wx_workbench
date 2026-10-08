import { request } from './index'
import type { Workout, WorkoutListResult, WorkoutPayload, WorkoutStats, WorkoutType } from '@/types'

export const listWorkouts = (params: {
  type?: WorkoutType
  from?: string
  to?: string
  page?: number
  pageSize?: number
} = {}) =>
  request<WorkoutListResult>({
    url: '/workout',
    method: 'GET',
    params,
  })

export const getWorkoutStats = (days = 7) =>
  request<WorkoutStats>({
    url: '/workout/stats',
    method: 'GET',
    params: { days },
  })

export const createWorkout = (data: WorkoutPayload) =>
  request<Workout>({
    url: '/workout',
    method: 'POST',
    data,
  })

export const updateWorkout = (id: number, data: Partial<WorkoutPayload>) =>
  request<Workout>({
    url: `/workout/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteWorkout = (id: number) =>
  request<{ success: boolean }>({
    url: `/workout/${id}`,
    method: 'DELETE',
  })

import { request } from './index'
import type { Habit, HabitPayload, HabitStats } from '@/types'

export const listHabits = () =>
  request<Habit[]>({
    url: '/habits',
    method: 'GET',
  })

export const getHabitStats = (days = 14) =>
  request<HabitStats>({
    url: '/habits/stats',
    method: 'GET',
    params: { days },
  })

export const createHabit = (data: HabitPayload) =>
  request<Habit>({
    url: '/habits',
    method: 'POST',
    data,
  })

export const updateHabit = (id: number, data: Partial<HabitPayload>) =>
  request<Habit>({
    url: `/habits/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteHabit = (id: number) =>
  request<{ success: boolean }>({
    url: `/habits/${id}`,
    method: 'DELETE',
  })

export const checkInHabit = (habitId: number) =>
  request<{ streakDays: number; checkedToday: boolean }>({
    url: `/habits/${habitId}/check-in`,
    method: 'POST',
  })

export const cancelHabitCheckIn = (habitId: number) =>
  request<{ streakDays: number; checkedToday: boolean }>({
    url: `/habits/${habitId}/check-in`,
    method: 'DELETE',
  })

import { request } from './index'
import type { LoginResult, User } from '@/types'

export const login = (payload: { username: string; password: string }) =>
  request<LoginResult>({
    url: '/auth/login',
    method: 'POST',
    data: payload,
  })

export const getProfile = () =>
  request<User>({
    url: '/auth/profile',
    method: 'GET',
  })

export const updateProfile = (payload: { nickname?: string; avatar?: string }) =>
  request<User>({
    url: '/auth/profile',
    method: 'PATCH',
    data: payload,
  })
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
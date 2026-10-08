import { request } from './index'
import type { User } from '@/types'

export const getUsers = () => request<User[]>({ url: '/users', method: 'GET' })

export const createUser = (payload: { username: string; password: string; role?: 'admin' | 'user' }) =>
  request<User>({ url: '/users', method: 'POST', data: payload })

export const removeUser = (id: number) => request<{ success: boolean }>({ url: `/users/${id}`, method: 'DELETE' })
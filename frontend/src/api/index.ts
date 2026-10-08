import axios, { type AxiosRequestConfig } from 'axios'
import { ElMessage } from 'element-plus'
import type { ApiResponse } from '@/types'

const TOKEN_KEY = 'life-workbench-token'

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

const service = axios.create({
  baseURL: API_BASE_URL,
  timeout: 12000,
  headers: {
    'Content-Type': 'application/json',
  },
})

service.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY)
  if (config.data instanceof FormData) {
    config.headers['Content-Type'] = undefined
  }

  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

service.interceptors.response.use(
  (response) => {
    const payload = response.data as ApiResponse<unknown>
    if (payload && typeof payload.code === 'number') {
      if (payload.code !== 0) {
        ElMessage.error(payload.message || '请求失败')
        return Promise.reject(new Error(payload.message || '请求失败'))
      }
      return payload.data
    }
    return response.data
  },
  (error) => {
    const status = error.response?.status
    const message = error.response?.data?.message || error.message || '网络连接异常'

    if (status === 401) {
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem('life-workbench-user')
      if (location.pathname !== '/login') {
        location.href = '/login'
      }
    } else {
      ElMessage.error(Array.isArray(message) ? message.join('；') : message)
    }

    return Promise.reject(error)
  },
)

export const request = <T>(config: AxiosRequestConfig) =>
  service.request<unknown, T>(config)

export const getToken = () => localStorage.getItem(TOKEN_KEY)
export const setToken = (token: string) => localStorage.setItem(TOKEN_KEY, token)
export const removeToken = () => localStorage.removeItem(TOKEN_KEY)

export default service
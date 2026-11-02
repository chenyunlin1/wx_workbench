import axios, { type AxiosRequestConfig, type InternalAxiosRequestConfig } from 'axios'
import { ElMessage } from 'element-plus'
import type { ApiResponse } from '@/types'

const TOKEN_KEY = 'life-workbench-token'
const REFRESH_TOKEN_KEY = 'life-workbench-refresh-token'
const USER_KEY = 'life-workbench-user'

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

const service = axios.create({
  baseURL: API_BASE_URL,
  timeout: 12000,
  headers: {
    'Content-Type': 'application/json',
  },
})

/** 续期专用：不走 service，避免刷新请求自己 401 时再触发一次刷新 */
const bare = axios.create({ baseURL: API_BASE_URL, timeout: 12000 })

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

interface RefreshData {
  accessToken?: string
  refreshToken?: string
}

async function requestNewAccessToken(): Promise<string> {
  const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY)
  if (!refreshToken) throw new Error('缺少 refreshToken')

  const { data } = await bare.post<ApiResponse<RefreshData>>('/auth/refresh', { refreshToken })
  const accessToken = data?.data?.accessToken
  if (!accessToken) throw new Error('续期失败')

  setToken(accessToken)
  const nextRefreshToken = data?.data?.refreshToken
  if (nextRefreshToken) localStorage.setItem(REFRESH_TOKEN_KEY, nextRefreshToken)
  return accessToken
}

/** 并发请求一起 401 时只发一次刷新，其余复用同一个 promise */
let refreshing: Promise<string> | null = null

export function refreshAccessToken(): Promise<string> {
  if (!refreshing) {
    refreshing = requestNewAccessToken().finally(() => {
      refreshing = null
    })
  }
  return refreshing
}

export const hasRefreshToken = () => Boolean(localStorage.getItem(REFRESH_TOKEN_KEY))

/** 会话确认过期（或后端还没有续期接口）：清干净回登录页 */
export function clearSessionAndGoLogin() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(REFRESH_TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
  if (location.pathname !== '/login') {
    location.href = '/login'
  }
}

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
  async (error) => {
    const status = error.response?.status
    const message = error.response?.data?.message || error.message || '网络连接异常'
    const config = error.config as (InternalAxiosRequestConfig & { retriedAfterRefresh?: boolean }) | undefined
    const url = config?.url ?? ''
    const isAuthEndpoint = url.includes('/auth/login') || url.includes('/auth/refresh')

    // accessToken 过期：先静默续期再原样重放这一次请求，用户不会被弹出登录页
    if (status === 401 && config && !config.retriedAfterRefresh && !isAuthEndpoint && hasRefreshToken()) {
      try {
        const token = await refreshAccessToken()
        config.retriedAfterRefresh = true
        config.headers.Authorization = `Bearer ${token}`
        return service.request(config)
      } catch {
        // 刷新也失败（refreshToken 过期 / 账号已删），才真的退回登录页
      }
    }

    if (status === 401) {
      clearSessionAndGoLogin()
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
export const setRefreshToken = (token: string) => localStorage.setItem(REFRESH_TOKEN_KEY, token)
export const removeRefreshToken = () => localStorage.removeItem(REFRESH_TOKEN_KEY)

export default service

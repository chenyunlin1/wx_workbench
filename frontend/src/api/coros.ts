import { request } from './index'
import type {
  CorosConnectResult,
  CorosDashboard,
  CorosStatus,
  CorosSyncStartResult,
} from '@/types'

/**
 * 高驰 MCP 走 OAuth 授权码 + PKCE：
 * connect 只给出授权页地址，真正的令牌交换由高驰回跳到后端 /coros/callback 完成，
 * 所以前端没有「提交 code」这一步，回到 /running 后重新拉 status 即可。
 *
 * 同步是后台任务：startCorosSync 立刻返回，进度靠轮询 getCorosStatus 的 sync 字段。
 */

export const getCorosStatus = () =>
  request<CorosStatus>({
    url: '/coros/status',
    method: 'GET',
  })

export const startCorosConnect = () =>
  request<CorosConnectResult>({
    url: '/coros/connect',
    method: 'POST',
  })

export const disconnectCoros = () =>
  request<{ success: boolean }>({
    url: '/coros/connection',
    method: 'DELETE',
  })

export const startCorosSync = (days?: number) =>
  request<CorosSyncStartResult>({
    url: '/coros/sync',
    method: 'POST',
    data: { days },
  })

export const getCorosDashboard = (days: number) =>
  request<CorosDashboard>({
    url: '/coros/dashboard',
    method: 'GET',
    params: { days },
  })

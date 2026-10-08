import { request } from './index'
import type { OpsCommand, OpsCommandPayload } from '@/types'

export const listOpsCommands = () =>
  request<OpsCommand[]>({
    url: '/ops',
    method: 'GET',
  })

export const createOpsCommand = (data: OpsCommandPayload) =>
  request<OpsCommand>({
    url: '/ops',
    method: 'POST',
    data,
  })

export const updateOpsCommand = (id: number, data: Partial<OpsCommandPayload>) =>
  request<OpsCommand>({
    url: `/ops/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteOpsCommand = (id: number) =>
  request<{ success: boolean }>({
    url: `/ops/${id}`,
    method: 'DELETE',
  })

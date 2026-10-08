import { request } from './index'
import type {
  CollectionItem,
  CollectionListResult,
  CollectionPayload,
  CollectionQuery,
  CollectionStats,
} from '@/types'

export const listCollection = (params: CollectionQuery = {}) =>
  request<CollectionListResult>({
    url: '/collection',
    method: 'GET',
    params,
  })

export const getCollectionStats = (year?: number) =>
  request<CollectionStats>({
    url: '/collection/stats',
    method: 'GET',
    params: year ? { year } : undefined,
  })

export const getCollectionYears = () =>
  request<number[]>({
    url: '/collection/years',
    method: 'GET',
  })

export const createCollection = (data: CollectionPayload) =>
  request<CollectionItem>({
    url: '/collection',
    method: 'POST',
    data,
  })

export const updateCollection = (id: number, data: Partial<CollectionPayload>) =>
  request<CollectionItem>({
    url: `/collection/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteCollection = (id: number) =>
  request<{ success: boolean }>({
    url: `/collection/${id}`,
    method: 'DELETE',
  })

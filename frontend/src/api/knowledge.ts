import { request } from './index'
import type {
  KnowledgeItem,
  KnowledgeListResult,
  KnowledgePayload,
  KnowledgeQuery,
  KnowledgeType,
} from '@/types'

export const listKnowledge = (params: KnowledgeQuery) =>
  request<KnowledgeListResult>({
    url: '/knowledge',
    method: 'GET',
    params,
  })

export const getKnowledgeDetail = (id: number) =>
  request<KnowledgeItem>({
    url: `/knowledge/${id}`,
    method: 'GET',
  })

export const createKnowledge = (data: KnowledgePayload & { type: KnowledgeType; title: string; content: string }) =>
  request<KnowledgeItem>({
    url: '/knowledge',
    method: 'POST',
    data,
  })

export const updateKnowledge = (id: number, data: KnowledgePayload) =>
  request<KnowledgeItem>({
    url: `/knowledge/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteKnowledge = (id: number) =>
  request<{ success: boolean }>({
    url: `/knowledge/${id}`,
    method: 'DELETE',
  })

export const getKnowledgeTags = () =>
  request<string[]>({
    url: '/knowledge/tags',
    method: 'GET',
  })

export const toggleKnowledgeLearned = (id: number, isLearned: boolean) =>
  updateKnowledge(id, { isLearned })

export const exportKnowledgeCsv = (params: KnowledgeQuery = {}) =>
  request<Blob>({
    url: '/knowledge/export',
    method: 'GET',
    params,
    responseType: 'blob',
  })

export const importKnowledgeCsv = (file: File) => {
  const formData = new FormData()
  formData.append('file', file)
  return request<{ imported: number; skipped: number }>({
    url: '/knowledge/import',
    method: 'POST',
    data: formData,
  })
}
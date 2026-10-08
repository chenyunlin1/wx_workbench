import { Film, Headset, Reading } from '@element-plus/icons-vue'
import type { Component } from 'vue'
import type { CollectionStatus, CollectionType } from '@/types'

export interface CollectionTypeMeta {
  value: CollectionType
  label: string
  icon: Component
  tone: 'blue' | 'violet' | 'green'
}

export const COLLECTION_TYPE_META: CollectionTypeMeta[] = [
  { value: 'book', label: '书籍', icon: Reading, tone: 'blue' },
  { value: 'movie', label: '影视', icon: Film, tone: 'violet' },
  { value: 'music', label: '音乐', icon: Headset, tone: 'green' },
]

export const typeMeta = (type: CollectionType): CollectionTypeMeta =>
  COLLECTION_TYPE_META.find((item) => item.value === type) ?? COLLECTION_TYPE_META[0]

export const STATUS_ORDER: CollectionStatus[] = ['wish', 'doing', 'done']

const STATUS_LABELS: Record<CollectionStatus, Record<CollectionType, string>> = {
  wish: { book: '想读', movie: '想看', music: '想听' },
  doing: { book: '在读', movie: '在看', music: '在听' },
  done: { book: '读完', movie: '看完', music: '听完' },
}

/** 状态文案随类型变化：书是「想读」，影视是「想看」，音乐是「想听」 */
export const statusLabel = (status: CollectionStatus, type: CollectionType) =>
  STATUS_LABELS[status][type]

export const nextStatus = (status: CollectionStatus): CollectionStatus =>
  status === 'wish' ? 'doing' : status === 'doing' ? 'done' : 'wish'

export const SORT_OPTIONS = [
  { value: 'createdAt', label: '最近添加' },
  { value: 'rating', label: '评分最高' },
  { value: 'year', label: '年份最新' },
  { value: 'title', label: '标题排序' },
] as const

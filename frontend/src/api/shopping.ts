import { request } from './index'
import type { ShoppingItem, ShoppingPayload } from '@/types'

export const listShopping = () =>
  request<ShoppingItem[]>({
    url: '/shopping',
    method: 'GET',
  })

export const createShoppingItem = (data: ShoppingPayload) =>
  request<ShoppingItem>({
    url: '/shopping',
    method: 'POST',
    data,
  })

export const updateShoppingItem = (id: number, data: Partial<ShoppingPayload>) =>
  request<ShoppingItem>({
    url: `/shopping/${id}`,
    method: 'PATCH',
    data,
  })

export const deleteShoppingItem = (id: number) =>
  request<{ success: boolean }>({
    url: `/shopping/${id}`,
    method: 'DELETE',
  })

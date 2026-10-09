import { defineStore } from 'pinia'
import { getProfile, login as loginApi, updateProfile as updateProfileApi } from '@/api/auth'
import { getToken, removeToken, setToken } from '@/api'
import type { User } from '@/types'

const USER_KEY = 'life-workbench-user'

const readUser = (): User | null => {
  try {
    const raw = localStorage.getItem(USER_KEY)
    return raw ? (JSON.parse(raw) as User) : null
  } catch {
    return null
  }
}

export const useUserStore = defineStore('user', {
  state: () => ({
    token: getToken() || '',
    user: readUser() as User | null,
  }),
  getters: {
    isLoggedIn: (state) => Boolean(state.token),
    isAdmin: (state) => state.user?.role === 'admin',
    displayName: (state) => state.user?.nickname || state.user?.username || '超级管理员',
  },
  actions: {
    async login(payload: { username: string; password: string }) {
      const result = await loginApi(payload)
      this.token = result.accessToken
      this.user = result.user
      setToken(result.accessToken)
      localStorage.setItem(USER_KEY, JSON.stringify(result.user))
      return result
    },
    async fetchProfile() {
      if (!this.token) return null
      this.user = await getProfile()
      localStorage.setItem(USER_KEY, JSON.stringify(this.user))
      return this.user
    },
    async updateProfile(payload: { nickname?: string; avatar?: string }) {
      this.user = await updateProfileApi(payload)
      localStorage.setItem(USER_KEY, JSON.stringify(this.user))
      return this.user
    },
    logout() {
      this.token = ''
      this.user = null
      removeToken()
      localStorage.removeItem(USER_KEY)
    },
  },
})
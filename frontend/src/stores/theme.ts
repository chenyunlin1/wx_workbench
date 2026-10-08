import { defineStore } from 'pinia'

export type ThemeMode = 'light' | 'dark'

const THEME_KEY = 'life-workbench-theme'

const getInitialTheme = (): ThemeMode => {
  const saved = localStorage.getItem(THEME_KEY) as ThemeMode | null
  if (saved === 'light' || saved === 'dark') return saved
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

const applyTheme = (theme: ThemeMode) => {
  const root = document.documentElement
  root.classList.toggle('dark', theme === 'dark')
  root.dataset.theme = theme
  root.style.colorScheme = theme
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', theme === 'dark' ? '#0b1120' : '#f5f7fb')
}

export const useThemeStore = defineStore('theme', {
  state: () => ({
    theme: getInitialTheme() as ThemeMode,
  }),
  getters: {
    isDark: (state) => state.theme === 'dark',
  },
  actions: {
    initialize() {
      applyTheme(this.theme)
    },
    toggle() {
      this.theme = this.theme === 'dark' ? 'light' : 'dark'
      localStorage.setItem(THEME_KEY, this.theme)
      applyTheme(this.theme)
    },
    setTheme(theme: ThemeMode) {
      this.theme = theme
      localStorage.setItem(THEME_KEY, theme)
      applyTheme(theme)
    },
  },
})
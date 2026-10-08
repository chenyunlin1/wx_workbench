<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowDown, ChatDotRound, Menu as MenuIcon, Moon, Sunny } from '@element-plus/icons-vue'
import { useThemeStore } from '@/stores/theme'
import { useUserStore } from '@/stores/user'

defineProps<{
  mobile?: boolean
}>()

const emit = defineEmits<{
  toggleSidebar: []
}>()

const route = useRoute()
const router = useRouter()
const themeStore = useThemeStore()
const userStore = useUserStore()

const pageTitle = computed(() => String(route.meta.title || '今日概览'))
const themeValue = computed({
  get: () => themeStore.theme,
  set: (value: 'light' | 'dark') => themeStore.setTheme(value),
})

const askAi = () => router.push('/ai')

const logout = () => {
  userStore.logout()
  router.replace('/login')
}
</script>

<template>
  <header class="app-header">
    <div class="header-left">
      <el-button
        v-if="mobile"
        class="menu-button"
        text
        circle
        aria-label="打开菜单"
        @click="emit('toggleSidebar')"
      >
        <el-icon><MenuIcon /></el-icon>
      </el-button>
      <div>
        <p>WORKSPACE</p>
        <h1>{{ pageTitle }}</h1>
      </div>
    </div>

    <div class="header-actions">
      <el-button class="ai-button" round @click="askAi">
        <el-icon><ChatDotRound /></el-icon>
        问问 AI
      </el-button>

      <div class="theme-switch">
        <el-icon class="sun"><Sunny /></el-icon>
        <el-switch
          v-model="themeValue"
          active-value="dark"
          inactive-value="light"
          inline-prompt
          :active-text="'月'"
          :inactive-text="'日'"
          aria-label="切换深浅色模式"
        />
        <el-icon class="moon"><Moon /></el-icon>
      </div>

      <el-dropdown trigger="click">
        <button class="profile-button" aria-label="用户菜单">
          <el-avatar :size="36" :src="userStore.user?.avatar || undefined">
            {{ userStore.displayName.slice(0, 1) }}
          </el-avatar>
          <span class="profile-copy">
            <strong>{{ userStore.displayName }}</strong>
            <small>{{ userStore.user?.role === 'admin' ? '管理员' : '用户' }}</small>
          </span>
          <el-icon><ArrowDown /></el-icon>
        </button>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item @click="router.push('/users')">个人设置</el-dropdown-item>
            <el-dropdown-item divided @click="logout">退出登录</el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </header>
</template>

<style scoped lang="scss">
.app-header {
  position: sticky;
  top: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 76px;
  padding: 0 26px;
  border-bottom: 1px solid var(--border-soft);
  background: var(--header-bg);
  backdrop-filter: blur(18px);
}

.header-left {
  display: flex;
  align-items: center;
  gap: 8px;
}

.header-left p {
  margin: 0 0 2px;
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.16em;
}

.header-left h1 {
  margin: 0;
  color: var(--text-primary);
  font-size: 21px;
  line-height: 1.2;
  letter-spacing: -0.025em;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 14px;
}

.menu-button {
  margin-right: 4px;
  color: var(--text-primary);
  font-size: 21px;
}

.ai-button {
  height: 38px;
  padding: 0 16px;
  border-color: color-mix(in srgb, var(--primary) 22%, var(--border-color));
  color: var(--primary-strong);
  background: var(--primary-soft);
}

.ai-button:hover {
  color: #fff;
  background: var(--primary);
}

.theme-switch {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 5px 9px;
  border: 1px solid var(--border-soft);
  border-radius: 999px;
  background: var(--surface-raised);
}

.theme-switch .el-icon {
  font-size: 15px;
}

.theme-switch .sun {
  color: #f59e0b;
}

.theme-switch .moon {
  color: #818cf8;
}

.theme-switch :deep(.el-switch) {
  --el-switch-on-color: #4f46e5;
  --el-switch-off-color: #f59e0b;
}

.profile-button {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 4px 6px 4px 4px;
  color: var(--text-regular);
  background: transparent;
  cursor: pointer;
}

.profile-copy {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.profile-copy strong {
  color: var(--text-primary);
  font-size: 13px;
}

.profile-copy small {
  margin-top: 1px;
  color: var(--text-secondary);
  font-size: 12px;
}

@media (max-width: 760px) {
  .app-header {
    min-height: 66px;
    padding: 0 14px;
  }

  .header-left h1 {
    font-size: 18px;
  }

  .header-left p,
  .profile-copy,
  .theme-switch > .el-icon:first-child {
    display: none;
  }

  .header-actions {
    gap: 7px;
  }

  .ai-button {
    width: 38px;
    padding: 0;
  }

  .ai-button :deep(span) {
    gap: 0;
    font-size: 0;
  }

  .ai-button .el-icon {
    margin: 0;
    font-size: 17px;
  }

  .theme-switch {
    padding: 4px;
  }
}
</style>
<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import {
  ChatDotRound,
  Checked,
  Collection,
  DataAnalysis,
  DocumentChecked,
  Bicycle,
  Histogram,
  HomeFilled,
  List,
  Monitor,
  MoreFilled,
  Notebook,
  Odometer,
  ShoppingCart,
  User,
  Wallet,
} from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'

defineProps<{
  inDrawer?: boolean
}>()

const emit = defineEmits<{
  navigate: []
}>()

const route = useRoute()
const userStore = useUserStore()

const activeMenu = computed(() => route.path)

const menuItems = [
  { path: '/dashboard', title: '今日概览', icon: HomeFilled },
  { path: '/finance', title: '记账理财', icon: Wallet },
  { path: '/habits', title: '习惯健康', icon: Checked },
  { path: '/fitness', title: '减脂健身', icon: Bicycle },
  { path: '/running', title: '跑步专项', icon: Odometer },
  { path: '/schedule', title: '日程统筹', icon: List },
  { path: '/shopping', title: '待买清单', icon: ShoppingCart },
  { path: '/collection', title: '书影音收藏', icon: Collection },
  { path: '/learning', title: '学习知识库', icon: Notebook },
  { path: '/practice', title: '知识练习', icon: DocumentChecked },
  { path: '/ops', title: '运维速查', icon: Monitor },
  { path: '/ai', title: 'AI 助手', icon: ChatDotRound },
  { path: '/users', title: '用户管理', icon: User },
]

const footerItems = [
  { label: '本月成长', value: '+12%', icon: DataAnalysis },
  { label: '连续记录', value: '8 天', icon: Histogram },
]
</script>

<template>
  <aside class="sidebar" :class="{ 'is-drawer': inDrawer }">
    <div class="brand">
      <div class="brand-mark">
        <span />
        <span />
        <span />
      </div>
      <div>
        <strong>LifeOS</strong>
        <small>个人生活工作台</small>
      </div>
    </div>

    <div class="user-panel">
      <el-avatar :size="42" :src="userStore.user?.avatar || undefined">
        {{ userStore.displayName.slice(0, 1) }}
      </el-avatar>
      <div class="user-copy">
        <strong>{{ userStore.displayName }}</strong>
        <span><i /> 超级管理员</span>
      </div>
      <el-icon class="user-more"><MoreFilled /></el-icon>
    </div>

    <nav class="menu-wrap" aria-label="主导航">
      <p class="menu-label">工作台</p>
      <el-menu
        :default-active="activeMenu"
        router
        class="nav-menu"
        @select="emit('navigate')"
      >
        <el-menu-item v-for="item in menuItems" :key="item.path" :index="item.path">
          <el-icon><component :is="item.icon" /></el-icon>
          <span>{{ item.title }}</span>
        </el-menu-item>
      </el-menu>
    </nav>

    <div class="sidebar-footer">
      <div v-for="item in footerItems" :key="item.label" class="footer-stat">
        <el-icon><component :is="item.icon" /></el-icon>
        <div>
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
        </div>
      </div>
      <p>保持节奏，缓慢积累。</p>
    </div>
  </aside>
</template>

<style scoped lang="scss">
.sidebar {
  display: flex;
  flex-direction: column;
  width: 220px;
  height: 100vh;
  padding: 18px 14px 16px;
  border-right: 1px solid var(--border-soft);
  background: var(--sidebar-bg);
  backdrop-filter: blur(20px);
}

.sidebar.is-drawer {
  width: 100%;
  height: 100%;
  border: 0;
  background: var(--surface);
}

.brand {
  display: flex;
  align-items: center;
  gap: 11px;
  height: 46px;
  padding: 0 9px;
  margin-bottom: 15px;
}

.brand-mark {
  position: relative;
  display: grid;
  grid-template-columns: repeat(2, 8px);
  gap: 3px;
  width: 30px;
  height: 30px;
  padding: 5px;
  border-radius: 10px;
  background: var(--primary);
  box-shadow: 0 7px 18px color-mix(in srgb, var(--primary) 30%, transparent);
}

.brand-mark span {
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.92);
}

.brand-mark span:last-child {
  grid-column: span 2;
  height: 4px;
}

.brand strong {
  display: block;
  color: var(--text-primary);
  font-size: 17px;
  line-height: 1.2;
  letter-spacing: -0.02em;
}

.brand small {
  color: var(--text-secondary);
  font-size: 12px;
  letter-spacing: 0.06em;
}

.user-panel {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 68px;
  padding: 12px;
  margin-bottom: 15px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: linear-gradient(135deg, var(--surface-muted), color-mix(in srgb, var(--primary-soft) 55%, var(--surface)));
}

.user-copy {
  min-width: 0;
  flex: 1;
}

.user-copy strong {
  display: block;
  overflow: hidden;
  color: var(--text-primary);
  font-size: 14px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-copy span {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 12px;
}

.user-copy i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--secondary);
  box-shadow: 0 0 0 3px var(--secondary-soft);
}

.user-more {
  color: var(--text-secondary);
}

.menu-wrap {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
}

.menu-label {
  padding: 0 10px;
  margin: 0 0 8px;
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.nav-menu {
  border-right: 0;
  background: transparent;
}

.nav-menu :deep(.el-menu-item) {
  height: 44px;
  padding: 0 12px !important;
  margin-bottom: 3px;
  border-radius: 11px;
  color: var(--text-regular);
  font-size: 14px;
  transition: all 0.2s ease;
}

.nav-menu :deep(.el-menu-item:hover) {
  color: var(--primary);
  background: var(--surface-hover);
}

.nav-menu :deep(.el-menu-item.is-active) {
  color: var(--primary-strong);
  font-weight: 700;
  background: linear-gradient(90deg, var(--primary-soft), color-mix(in srgb, var(--primary-soft) 35%, transparent));
}

.nav-menu :deep(.el-menu-item.is-active::after) {
  position: absolute;
  right: 7px;
  width: 4px;
  height: 18px;
  border-radius: 99px;
  background: var(--primary);
  content: '';
}

.nav-menu :deep(.el-icon) {
  width: 20px;
  margin-right: 10px;
  font-size: 18px;
}

.sidebar-footer {
  padding: 12px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-muted);
}

.footer-stat {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 5px 0;
}

.footer-stat .el-icon {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  color: var(--primary);
  background: var(--primary-soft);
}

.footer-stat div {
  display: flex;
  flex: 1;
  align-items: center;
  justify-content: space-between;
}

.footer-stat span,
.sidebar-footer p {
  color: var(--text-secondary);
  font-size: 12px;
}

.footer-stat strong {
  color: var(--text-primary);
  font-size: 13px;
}

.sidebar-footer p {
  margin: 7px 0 0;
  text-align: center;
}

@media (max-height: 760px) {
  .sidebar-footer {
    display: none;
  }
}
</style>
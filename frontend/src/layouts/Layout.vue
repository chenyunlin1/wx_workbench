<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Sidebar from '@/components/layout/Sidebar.vue'
import AppHeader from '@/components/layout/Header.vue'

const route = useRoute()
const router = useRouter()
const mobileOpen = ref(false)
const isMobile = ref(false)
let mediaQuery: MediaQueryList | null = null

const syncViewport = (event?: MediaQueryListEvent) => {
  isMobile.value = event ? event.matches : Boolean(mediaQuery?.matches)
  if (!isMobile.value) mobileOpen.value = false
}

onMounted(() => {
  mediaQuery = window.matchMedia('(max-width: 900px)')
  syncViewport()
  mediaQuery.addEventListener('change', syncViewport)
})

onBeforeUnmount(() => mediaQuery?.removeEventListener('change', syncViewport))

const closeDrawer = () => {
  mobileOpen.value = false
}

const handleNavigate = () => {
  closeDrawer()
  if (route.name === 'dashboard') router.replace('/dashboard')
}
</script>

<template>
  <div class="app-shell">
    <div v-if="!isMobile" class="desktop-sidebar">
      <Sidebar />
    </div>

    <el-drawer
      v-model="mobileOpen"
      direction="ltr"
      :with-header="false"
      size="min(84vw, 290px)"
      class="sidebar-drawer"
    >
      <Sidebar in-drawer @navigate="handleNavigate" />
    </el-drawer>

    <div class="main-shell">
      <AppHeader :mobile="isMobile" @toggle-sidebar="mobileOpen = true" />
      <main class="main-content">
        <router-view v-slot="{ Component }">
          <transition name="page" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </main>
    </div>
  </div>
</template>

<style scoped lang="scss">
.app-shell {
  display: flex;
  min-height: 100vh;
}

.desktop-sidebar {
  position: fixed;
  inset: 0 auto 0 0;
  z-index: 30;
}

.main-shell {
  width: calc(100% - 220px);
  min-width: 0;
  margin-left: 220px;
}

.main-content {
  width: 100%;
  max-width: 1720px;
  min-height: calc(100vh - 76px);
  padding: 26px 28px 36px;
  margin: 0 auto;
}

@media (max-width: 900px) {
  .main-shell {
    width: 100%;
    margin-left: 0;
  }
}

@media (max-width: 760px) {
  .main-content {
    padding: 18px 14px 28px;
  }
}
</style>

<style lang="scss">
.sidebar-drawer .el-drawer__body {
  padding: 0;
  background: var(--surface);
}
</style>
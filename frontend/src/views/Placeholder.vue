<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Tools } from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const title = computed(() => String(route.meta.title || '功能页面'))
</script>

<template>
  <section class="placeholder-page">
    <div class="placeholder-card">
      <span class="placeholder-icon"><el-icon><Tools /></el-icon></span>
      <p>MODULE READY</p>
      <h2>{{ title }}</h2>
      <span>该模块的后端 CRUD 接口已就绪，可在此继续扩展业务界面。</span>
      <el-button type="primary" @click="router.push('/dashboard')">
        <el-icon><ArrowLeft /></el-icon>
        返回今日概览
      </el-button>
    </div>
  </section>
</template>

<style scoped lang="scss">
.placeholder-page {
  display: grid;
  min-height: calc(100vh - 150px);
  place-items: center;
}

.placeholder-card {
  width: min(480px, 100%);
  padding: 50px 34px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-lg);
  text-align: center;
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.placeholder-icon {
  display: grid;
  width: 66px;
  height: 66px;
  margin: 0 auto 18px;
  place-items: center;
  border-radius: 20px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 30px;
}

.placeholder-card p {
  margin: 0 0 8px;
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.18em;
}

.placeholder-card h2 {
  margin: 0 0 10px;
  color: var(--text-primary);
  font-size: 26px;
}

.placeholder-card > span:not(.placeholder-icon) {
  display: block;
  margin-bottom: 25px;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.8;
}
</style>
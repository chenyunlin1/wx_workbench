<script setup lang="ts">
import { useRouter } from 'vue-router'
import { ArrowRight, Collection, Bicycle, Monitor, ShoppingCart } from '@element-plus/icons-vue'

const router = useRouter()

const actions = [
  { label: '运维速查', description: '常用命令', path: '/ops', icon: Monitor, color: 'blue' },
  { label: '书影音', description: '收藏灵感', path: '/collection', icon: Collection, color: 'violet' },
  { label: '健身', description: '训练记录', path: '/fitness', icon: Bicycle, color: 'green' },
  { label: '待买', description: '购物清单', path: '/shopping', icon: ShoppingCart, color: 'rose' },
]
</script>

<template>
  <el-card class="dashboard-card quick-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div>
          <h3>快捷入口</h3>
          <p>常用功能，一步直达</p>
        </div>
        <el-icon class="sparkle"><ArrowRight /></el-icon>
      </div>
    </template>

    <div class="quick-grid">
      <button
        v-for="action in actions"
        :key="action.path"
        class="quick-action"
        :class="action.color"
        @click="router.push(action.path)"
      >
        <span class="quick-icon"><el-icon><component :is="action.icon" /></el-icon></span>
        <strong>{{ action.label }}</strong>
        <small>{{ action.description }}</small>
      </button>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.quick-card {
  min-height: 286px;
  background:
    linear-gradient(145deg, color-mix(in srgb, var(--primary-soft) 50%, var(--surface)), var(--surface) 58%),
    var(--surface-raised);
}

.card-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 16px;
}

.card-heading p {
  margin: 3px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.sparkle {
  color: var(--primary);
  font-size: 19px;
}

.quick-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 11px;
  padding-top: 7px;
}

.quick-action {
  display: flex;
  min-height: 92px;
  flex-direction: column;
  align-items: flex-start;
  padding: 12px;
  border: 1px solid var(--border-soft);
  border-radius: 14px;
  color: var(--text-primary);
  background: color-mix(in srgb, var(--surface) 88%, transparent);
  box-shadow: var(--shadow-xs);
  cursor: pointer;
  transition: all 0.22s ease;
}

.quick-action:hover {
  border-color: color-mix(in srgb, var(--primary) 35%, var(--border-color));
  box-shadow: var(--shadow-sm);
  transform: translateY(-3px);
}

.quick-icon {
  display: grid;
  width: 32px;
  height: 32px;
  margin-bottom: 9px;
  place-items: center;
  border-radius: 10px;
  font-size: 17px;
}

.quick-action strong {
  font-size: 13px;
}

.quick-action small {
  margin-top: 2px;
  color: var(--text-secondary);
  font-size: 12px;
}

.quick-action.blue .quick-icon {
  color: var(--primary);
  background: var(--primary-soft);
}

.quick-action.violet .quick-icon {
  color: var(--accent);
  background: color-mix(in srgb, var(--accent) 14%, transparent);
}

.quick-action.green .quick-icon {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.quick-action.rose .quick-icon {
  color: #f43f5e;
  background: color-mix(in srgb, #f43f5e 12%, transparent);
}

@media (max-width: 420px) {
  .quick-grid {
    grid-template-columns: 1fr;
  }
}
</style>
<script setup lang="ts">
import { ArrowRight, ShoppingBag, ShoppingCart } from '@element-plus/icons-vue'
import type { ShoppingItem } from '@/types'

defineProps<{
  items: ShoppingItem[]
  loading?: boolean
}>()
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card shopping-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon rose"><el-icon><ShoppingCart /></el-icon></span>
          <div>
            <h3>待买提醒</h3>
            <p>理性消费，按需购买</p>
          </div>
        </div>
        <router-link class="text-link" to="/shopping">待买清单 <el-icon><ArrowRight /></el-icon></router-link>
      </div>
    </template>

    <div v-if="items.length" class="shopping-list">
      <div v-for="item in items.slice(0, 3)" :key="item.id" class="shopping-item">
        <span class="item-check" :class="{ bought: item.status === 'bought' }" />
        <div>
          <strong>{{ item.name }}</strong>
          <small>{{ item.status === 'bought' ? '已经购买' : '等待购买' }}</small>
        </div>
        <span class="price">¥{{ Number(item.price).toFixed(2) }}</span>
      </div>
    </div>

    <div v-else class="shopping-empty">
      <div class="bag-visual">
        <el-icon><ShoppingBag /></el-icon>
        <i />
      </div>
      <strong>暂无待买物品</strong>
      <p>把想买的东西先记下来，避免冲动消费</p>
      <router-link to="/shopping">添加待买物品</router-link>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.shopping-card {
  min-height: 286px;
}

.card-heading,
.heading-copy,
.text-link {
  display: flex;
  align-items: center;
}

.card-heading {
  justify-content: space-between;
  gap: 12px;
}

.heading-copy {
  gap: 10px;
}

.heading-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 11px;
  font-size: 18px;
}

.heading-icon.rose {
  color: #f43f5e;
  background: color-mix(in srgb, #f43f5e 12%, transparent);
}

h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 16px;
}

.heading-copy p {
  margin: 3px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.text-link {
  gap: 2px;
  color: var(--text-secondary);
  font-size: 13px;
}

.text-link:hover {
  color: var(--primary);
}

.shopping-list {
  display: grid;
  gap: 9px;
  padding-top: 5px;
}

.shopping-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 11px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
}

.item-check {
  width: 18px;
  height: 18px;
  flex: none;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--surface);
}

.item-check.bought {
  border-color: var(--secondary);
  background: var(--secondary);
  box-shadow: inset 0 0 0 4px var(--surface);
}

.shopping-item > div {
  min-width: 0;
  flex: 1;
}

.shopping-item strong,
.shopping-item small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.shopping-item strong {
  color: var(--text-primary);
  font-size: 13px;
}

.shopping-item small {
  margin-top: 2px;
  color: var(--text-secondary);
  font-size: 12px;
}

.price {
  color: var(--text-primary);
  font-size: 13px;
  font-weight: 700;
}

.shopping-empty {
  padding-top: 23px;
  text-align: center;
}

.bag-visual {
  position: relative;
  display: grid;
  width: 58px;
  height: 58px;
  margin: 0 auto 12px;
  place-items: center;
  border-radius: 18px;
  color: #f43f5e;
  background: color-mix(in srgb, #f43f5e 12%, var(--surface));
  font-size: 25px;
}

.bag-visual i {
  position: absolute;
  right: 6px;
  bottom: 7px;
  width: 8px;
  height: 8px;
  border: 2px solid var(--surface);
  border-radius: 50%;
  background: var(--secondary);
}

.shopping-empty strong {
  display: block;
  font-size: 14px;
}

.shopping-empty p {
  margin: 5px 0 12px;
  color: var(--text-secondary);
  font-size: 12px;
}

.shopping-empty a {
  display: inline-block;
  padding: 6px 11px;
  border-radius: 8px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 12px;
  font-weight: 700;
}
</style>
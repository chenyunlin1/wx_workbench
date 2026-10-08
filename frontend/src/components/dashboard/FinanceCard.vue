<script setup lang="ts">
import { computed } from 'vue'
import { ArrowRight, TrendCharts, Wallet } from '@element-plus/icons-vue'

const props = defineProps<{
  income: number
  expense: number
  balance: number
  loading?: boolean
}>()

const display = (value: number) => value.toLocaleString('zh-CN', { maximumFractionDigits: 2 })
const total = computed(() => Math.max(props.income + props.expense, 1))
const incomeWidth = computed(() => `${Math.max((props.income / total.value) * 100, 4)}%`)
const expenseWidth = computed(() => `${Math.max((props.expense / total.value) * 100, 4)}%`)
</script>

<template>
  <el-card v-loading="loading" class="dashboard-card finance-card" shadow="never">
    <template #header>
      <div class="card-heading">
        <div class="heading-copy">
          <span class="heading-icon blue"><el-icon><Wallet /></el-icon></span>
          <div>
            <h3>财务概况</h3>
            <p>本月收支一目了然</p>
          </div>
        </div>
        <router-link class="text-link" to="/finance">本月 <el-icon><ArrowRight /></el-icon></router-link>
      </div>
    </template>

    <div class="balance-panel">
      <div>
        <span>本月结余</span>
        <strong><small>¥</small>{{ display(balance) }}</strong>
      </div>
      <div class="trend-badge" :class="{ negative: balance < 0 }">
        <el-icon><TrendCharts /></el-icon>
        {{ balance >= 0 ? '收支稳健' : '需要关注' }}
      </div>
    </div>

    <div class="finance-stats">
      <div>
        <span class="stat-dot income" />
        <div>
          <small>收入</small>
          <strong>+{{ display(income) }}</strong>
        </div>
      </div>
      <div>
        <span class="stat-dot expense" />
        <div>
          <small>支出</small>
          <strong>-{{ display(expense) }}</strong>
        </div>
      </div>
    </div>

    <div class="finance-bars">
      <div class="bar-row">
        <span>收入</span>
        <i><b class="income" :style="{ width: incomeWidth }" /></i>
      </div>
      <div class="bar-row">
        <span>支出</span>
        <i><b class="expense" :style="{ width: expenseWidth }" /></i>
      </div>
    </div>
  </el-card>
</template>

<style scoped lang="scss">
.finance-card {
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

.heading-icon.blue {
  color: var(--primary);
  background: var(--primary-soft);
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

.balance-panel {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 6px 2px 15px;
  border-bottom: 1px solid var(--border-soft);
}

.balance-panel span {
  display: block;
  margin-bottom: 5px;
  color: var(--text-secondary);
  font-size: 12px;
}

.balance-panel strong {
  color: var(--text-primary);
  font-size: 29px;
  line-height: 1;
  letter-spacing: -0.04em;
}

.balance-panel strong small {
  margin-right: 4px;
  color: var(--primary);
  font-size: 14px;
}

.trend-badge {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 5px 8px;
  border-radius: 99px;
  color: var(--secondary);
  background: var(--secondary-soft);
  font-size: 12px;
}

.trend-badge.negative {
  color: var(--danger);
  background: color-mix(in srgb, var(--danger) 12%, transparent);
}

.finance-stats {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
  padding: 14px 0 12px;
}

.finance-stats > div {
  display: flex;
  align-items: center;
  gap: 9px;
}

.stat-dot {
  width: 8px;
  height: 28px;
  border-radius: 99px;
}

.stat-dot.income {
  background: var(--secondary);
}

.stat-dot.expense {
  background: var(--danger);
}

.finance-stats small,
.finance-stats strong {
  display: block;
}

.finance-stats small {
  color: var(--text-secondary);
  font-size: 12px;
}

.finance-stats strong {
  margin-top: 2px;
  color: var(--text-primary);
  font-size: 14px;
}

.finance-stats > div:first-child strong {
  color: var(--secondary);
}

.finance-stats > div:last-child strong {
  color: var(--danger);
}

.finance-bars {
  display: grid;
  gap: 8px;
}

.bar-row {
  display: grid;
  grid-template-columns: 30px 1fr;
  align-items: center;
  gap: 8px;
}

.bar-row > span {
  color: var(--text-secondary);
  font-size: 12px;
}

.bar-row > i {
  height: 6px;
  overflow: hidden;
  border-radius: 99px;
  background: var(--surface-muted);
}

.bar-row b {
  display: block;
  height: 100%;
  min-width: 5px;
  border-radius: inherit;
  transition: width 0.5s ease;
}

.bar-row b.income {
  background: var(--secondary);
}

.bar-row b.expense {
  background: var(--danger);
}
</style>
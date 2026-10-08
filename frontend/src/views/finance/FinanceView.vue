<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import dayjs from 'dayjs'
import { ArrowDownBold, ArrowUpBold, Calendar, Delete, Edit, Plus, Wallet } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { createFinance, deleteFinance, getFinanceCategories, getFinanceSummary, listFinance, updateFinance } from '@/api/finance'
import FinanceFormDialog from './components/FinanceFormDialog.vue'
import type { Finance, FinanceFormPayload, FinanceSummary } from '@/types'

const summary = ref<FinanceSummary>({ month: '', income: 0, expense: 0, balance: 0 })
const records = ref<Finance[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const loading = ref(false)
const saving = ref(false)
const typeFilter = ref<'' | 'income' | 'expense'>('')
const categoryFilter = ref('')
const monthFilter = ref('')
const dialogVisible = ref(false)
const editingRecord = ref<Finance | null>(null)
const categories = ref<string[]>(['餐饮', '交通', '薪资', '购物', '娱乐', '住房'])

const currentMonth = dayjs().format('YYYY-MM')
const monthOptions = computed(() => Array.from({ length: 12 }, (_, index) => {
  const month = dayjs().subtract(index, 'month')
  return { value: month.format('YYYY-MM'), label: month.format('YYYY年MM月') }
}))

const displayAmount = (value: number) => Number(value || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const recordDate = (value: string) => dayjs(value).format('YYYY/MM/DD HH:mm')

const loadSummary = async () => {
  summary.value = await getFinanceSummary(currentMonth)
}

const loadRecords = async () => {
  loading.value = true
  try {
    const result = await listFinance({
      type: typeFilter.value || undefined,
      category: categoryFilter.value || undefined,
      month: monthFilter.value || undefined,
      page: page.value,
      pageSize: pageSize.value,
    })
    records.value = result.items
    total.value = result.total
  } finally {
    loading.value = false
  }
}

const loadCategories = async () => {
  const result = await getFinanceCategories()
  categories.value = [...new Set(['餐饮', '交通', '薪资', '购物', '娱乐', '住房', ...result])]
}

const refresh = async () => {
  await Promise.all([loadSummary(), loadRecords()])
}

const openCreate = () => {
  editingRecord.value = null
  dialogVisible.value = true
}

const openEdit = (record: Finance) => {
  editingRecord.value = record
  dialogVisible.value = true
}

const handleSave = async (payload: FinanceFormPayload) => {
  saving.value = true
  try {
    if (editingRecord.value) await updateFinance(editingRecord.value.id, payload)
    else await createFinance(payload)
    ElMessage.success(editingRecord.value ? '记录已更新' : '已记账')
    dialogVisible.value = false
    await Promise.all([refresh(), loadCategories()])
  } finally {
    saving.value = false
  }
}

const handleDelete = async (record: Finance) => {
  await ElMessageBox.confirm('确定删除这笔记录吗？', '删除记录', { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' })
  await deleteFinance(record.id)
  ElMessage.success('记录已删除')
  if (records.value.length === 1 && page.value > 1) page.value -= 1
  await refresh()
}

watch([typeFilter, categoryFilter, monthFilter], () => {
  page.value = 1
  loadRecords()
})

watch(page, loadRecords)

onMounted(async () => {
  await Promise.all([refresh(), loadCategories()])
})
</script>

<template>
  <section class="finance-page">
    <header class="page-heading">
      <p>FINANCE OVERVIEW</p>
      <h2>记账理财</h2>
      <span>每一笔记录，都是生活轨迹的一部分。</span>
    </header>

    <div class="summary-grid">
      <div class="summary-card income-card">
        <span class="summary-icon"><el-icon><ArrowUpBold /></el-icon></span>
        <div><small>本月收入</small><strong class="income">+¥{{ displayAmount(summary.income) }}</strong></div>
      </div>
      <div class="summary-card expense-card">
        <span class="summary-icon"><el-icon><ArrowDownBold /></el-icon></span>
        <div><small>本月支出</small><strong class="expense">-¥{{ displayAmount(summary.expense) }}</strong></div>
      </div>
      <div class="summary-card balance-card">
        <span class="summary-icon"><el-icon><Wallet /></el-icon></span>
        <div><small>本月结余</small><strong class="balance">{{ summary.balance < 0 ? '-' : '' }}¥{{ displayAmount(Math.abs(summary.balance)) }}</strong></div>
      </div>
    </div>

    <section class="filter-bar">
      <div class="filter-left">
        <el-select v-model="typeFilter" placeholder="全部类型" clearable>
          <el-option label="全部类型" value="" />
          <el-option label="收入" value="income" />
          <el-option label="支出" value="expense" />
        </el-select>
        <el-select v-model="categoryFilter" placeholder="全部类别" clearable>
          <el-option label="全部类别" value="" />
          <el-option v-for="category in categories" :key="category" :label="category" :value="category" />
        </el-select>
        <el-select v-model="monthFilter" placeholder="全部月份" clearable>
          <el-option label="全部月份" value="" />
          <el-option v-for="month in monthOptions" :key="month.value" :label="month.label" :value="month.value" />
        </el-select>
      </div>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon>记一笔</el-button>
    </section>

    <section class="record-card">
      <div v-if="!loading && !records.length" class="empty-record">
        <span class="empty-icon"><el-icon><Wallet /></el-icon></span>
        <strong>暂无记录，点击右上角「记一笔」开始</strong>
        <p>从今天的第一笔收支开始记录吧</p>
      </div>

      <div v-else v-loading="loading" class="record-list">
        <article v-for="record in records" :key="record.id" class="record-row">
          <span class="record-icon" :class="record.type"><el-icon><ArrowUpBold v-if="record.type === 'income'" /><ArrowDownBold v-else /></el-icon></span>
          <div class="record-main">
            <strong>{{ record.category }}</strong>
            <span>{{ record.remark || '无备注' }}</span>
          </div>
          <strong class="record-amount" :class="record.type">{{ record.type === 'income' ? '+' : '-' }}¥{{ displayAmount(record.amount) }}</strong>
          <span class="record-date"><el-icon><Calendar /></el-icon>{{ recordDate(record.recordDate) }}</span>
          <div class="record-actions">
            <el-button text size="small" @click="openEdit(record)"><el-icon><Edit /></el-icon>编辑</el-button>
            <el-button text size="small" type="danger" @click="handleDelete(record)"><el-icon><Delete /></el-icon>删除</el-button>
          </div>
        </article>
      </div>

      <div v-if="total > pageSize" class="pagination-wrap">
        <el-pagination v-model:current-page="page" :page-size="pageSize" :total="total" layout="prev, pager, next" background />
      </div>
    </section>

    <FinanceFormDialog v-model="dialogVisible" :record="editingRecord" :categories="categories" :saving="saving" @save="handleSave" />
  </section>
</template>

<style scoped lang="scss">
.finance-page { display: grid; gap: 18px; animation: finance-in 0.35s ease both; }
@keyframes finance-in { from { opacity: 0; transform: translateY(7px); } }
.page-heading p { margin: 0 0 6px; color: var(--primary); font-size: 12px; font-weight: 800; letter-spacing: 0.18em; }
.page-heading h2 { margin: 0; color: var(--text-primary); font-size: 28px; letter-spacing: -0.04em; }
.page-heading span { display: block; margin-top: 7px; color: var(--text-secondary); font-size: 13px; }
.summary-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
.summary-card { display: flex; min-height: 112px; align-items: center; gap: 14px; padding: 20px; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-sm); }
.summary-icon { display: grid; width: 44px; height: 44px; flex: none; place-items: center; border-radius: 13px; font-size: 20px; }
.income-card .summary-icon { color: var(--secondary); background: var(--secondary-soft); }
.expense-card .summary-icon { color: var(--danger); background: color-mix(in srgb, var(--danger) 12%, transparent); }
.balance-card .summary-icon { color: var(--primary); background: var(--primary-soft); }
.summary-card small { display: block; margin-bottom: 8px; color: var(--text-secondary); font-size: 12px; }
.summary-card strong { font-size: 24px; letter-spacing: -0.035em; }
.income { color: var(--secondary); }
.expense { color: var(--danger); }
.balance { color: var(--text-primary); }
.filter-bar { display: flex; align-items: center; justify-content: space-between; gap: 15px; padding: 14px 16px; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-xs); }
.filter-left { display: flex; min-width: 0; gap: 10px; }
.filter-left :deep(.el-select) { width: 145px; }
.record-card { min-height: 280px; padding: 15px; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-sm); }
.record-list { display: grid; gap: 9px; }
.record-row { display: grid; grid-template-columns: 42px minmax(120px, 1fr) 120px 150px auto; align-items: center; gap: 12px; padding: 12px 14px; border: 1px solid var(--border-soft); border-radius: 12px; background: var(--surface-muted); transition: all 0.18s ease; }
.record-row:hover { border-color: color-mix(in srgb, var(--primary) 25%, var(--border-color)); background: color-mix(in srgb, var(--primary-soft) 30%, var(--surface)); }
.record-icon { display: grid; width: 38px; height: 38px; place-items: center; border-radius: 12px; font-size: 18px; }
.record-icon.income { color: var(--secondary); background: var(--secondary-soft); }
.record-icon.expense { color: var(--danger); background: color-mix(in srgb, var(--danger) 12%, transparent); }
.record-main { min-width: 0; }
.record-main strong, .record-main span { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.record-main strong { color: var(--text-primary); font-size: 14px; }
.record-main span { margin-top: 4px; color: var(--text-secondary); font-size: 12px; }
.record-amount { font-size: 16px; text-align: right; }
.record-amount.income { color: var(--secondary); }
.record-amount.expense { color: var(--danger); }
.record-date { display: flex; align-items: center; gap: 5px; color: var(--text-secondary); font-size: 12px; }
.record-actions { display: flex; justify-content: flex-end; }
.record-actions :deep(.el-button) { margin-left: 2px; }
.empty-record { display: grid; min-height: 250px; place-items: center; align-content: center; text-align: center; }
.empty-icon { display: grid; width: 62px; height: 62px; margin-bottom: 13px; place-items: center; border: 1px dashed color-mix(in srgb, var(--primary) 30%, var(--border-color)); border-radius: 20px; color: var(--primary); background: var(--primary-soft); font-size: 26px; }
.empty-record strong { color: var(--text-primary); font-size: 14px; }
.empty-record p { margin: 6px 0 0; color: var(--text-secondary); font-size: 12px; }
.pagination-wrap { display: flex; justify-content: flex-end; padding-top: 15px; }
@media (max-width: 860px) {
  .summary-grid { grid-template-columns: 1fr; }
  .filter-bar { align-items: stretch; flex-direction: column; }
  .filter-left { flex-wrap: wrap; }
  .record-row { grid-template-columns: 42px minmax(100px, 1fr) auto; }
  .record-date { display: none; }
  .record-actions { grid-column: span 3; justify-content: flex-end; }
}
@media (max-width: 540px) {
  .filter-left :deep(.el-select) { width: 100%; }
  .record-row { grid-template-columns: 38px 1fr auto; padding: 11px; }
  .record-amount { font-size: 14px; }
}
</style>

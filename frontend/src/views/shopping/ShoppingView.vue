<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import dayjs from 'dayjs'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Check,
  Delete,
  Edit,
  Plus,
  ShoppingCart,
  Wallet,
} from '@element-plus/icons-vue'
import {
  createShoppingItem,
  deleteShoppingItem,
  listShopping,
  updateShoppingItem,
} from '@/api/shopping'
import ShoppingFormDialog from './components/ShoppingFormDialog.vue'
import type { ShoppingItem, ShoppingPayload } from '@/types'

type FilterValue = 'all' | 'pending' | 'bought'
type SortValue = 'recent' | 'priceDesc' | 'priceAsc'

const SOURCE_OPTIONS: Array<{ value: SortValue; label: string }> = [
  { value: 'recent', label: '最近添加' },
  { value: 'priceDesc', label: '价格从高到低' },
  { value: 'priceAsc', label: '价格从低到高' },
]

const items = ref<ShoppingItem[]>([])
const loading = ref(false)
const saving = ref(false)
const filter = ref<FilterValue>('all')
const sortBy = ref<SortValue>('recent')
const keyword = ref('')

const quickName = ref('')
const quickPrice = ref<number | null>(null)
const quickAdding = ref(false)

const dialogVisible = ref(false)
const editing = ref<ShoppingItem | null>(null)

const money = (value: number) =>
  Number(value || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

const pendingItems = computed(() => items.value.filter((item) => item.status === 'pending'))
const boughtItems = computed(() => items.value.filter((item) => item.status === 'bought'))
const pendingTotal = computed(() =>
  pendingItems.value.reduce((sum, item) => sum + Number(item.price), 0),
)
const boughtTotal = computed(() =>
  boughtItems.value.reduce((sum, item) => sum + Number(item.price), 0),
)
const averagePrice = computed(() =>
  pendingItems.value.length ? pendingTotal.value / pendingItems.value.length : 0,
)

const visibleItems = computed(() => {
  const keywordValue = keyword.value.trim().toLowerCase()
  const filtered = items.value.filter((item) => {
    if (filter.value === 'pending' && item.status !== 'pending') return false
    if (filter.value === 'bought' && item.status !== 'bought') return false
    if (keywordValue && !item.name.toLowerCase().includes(keywordValue)) return false
    return true
  })

  const sorted = [...filtered]
  if (sortBy.value === 'priceDesc') sorted.sort((a, b) => Number(b.price) - Number(a.price))
  else if (sortBy.value === 'priceAsc') sorted.sort((a, b) => Number(a.price) - Number(b.price))
  else sorted.sort((a, b) => b.id - a.id)
  return sorted
})

const load = async () => {
  loading.value = true
  try {
    items.value = await listShopping()
  } finally {
    loading.value = false
  }
}

const quickAdd = async () => {
  const name = quickName.value.trim()
  if (!name) {
    ElMessage.warning('先输入物品名称')
    return
  }
  quickAdding.value = true
  try {
    await createShoppingItem({
      name,
      price: quickPrice.value === null ? 0 : Number(Number(quickPrice.value).toFixed(2)),
      status: 'pending',
    })
    quickName.value = ''
    quickPrice.value = null
    ElMessage.success('已加入待买清单')
    await load()
  } finally {
    quickAdding.value = false
  }
}

const toggleBought = async (item: ShoppingItem) => {
  const next = item.status === 'pending' ? 'bought' : 'pending'
  const updated = await updateShoppingItem(item.id, { status: next })
  item.status = updated.status
  ElMessage.success(next === 'bought' ? `「${item.name}」已标记为买到` : `「${item.name}」已恢复待买`)
}

const openCreate = () => {
  editing.value = null
  dialogVisible.value = true
}

const openEdit = (item: ShoppingItem) => {
  editing.value = item
  dialogVisible.value = true
}

const handleSave = async (payload: ShoppingPayload) => {
  saving.value = true
  try {
    if (editing.value) await updateShoppingItem(editing.value.id, payload)
    else await createShoppingItem(payload)
    ElMessage.success(editing.value ? '物品已更新' : '已加入待买清单')
    dialogVisible.value = false
    await load()
  } finally {
    saving.value = false
  }
}

const handleDelete = async (item: ShoppingItem) => {
  await ElMessageBox.confirm(`确定删除「${item.name}」吗？`, '删除物品', {
    type: 'warning',
    confirmButtonText: '删除',
    cancelButtonText: '取消',
  })
  await deleteShoppingItem(item.id)
  ElMessage.success('已删除')
  await load()
}

const clearBought = async () => {
  const targets = boughtItems.value
  if (!targets.length) {
    ElMessage.info('还没有已买的物品')
    return
  }
  await ElMessageBox.confirm(`确定删除 ${targets.length} 条已买记录吗？`, '清理已买', {
    type: 'warning',
    confirmButtonText: '清理',
    cancelButtonText: '取消',
  })
  await Promise.all(targets.map((item) => deleteShoppingItem(item.id)))
  ElMessage.success(`已清理 ${targets.length} 条记录`)
  await load()
}

onMounted(load)
</script>

<template>
  <section class="shopping-page">
    <header class="page-heading">
      <div>
        <p>SHOPPING LIST</p>
        <h2>待买清单</h2>
        <span>想买的东西先记下来，冷静几天再决定。</span>
      </div>
      <div class="heading-actions">
        <el-button :disabled="!boughtItems.length" @click="clearBought">
          <el-icon><Delete /></el-icon>清理已买
        </el-button>
        <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon>新增物品</el-button>
      </div>
    </header>

    <div class="summary-grid">
      <div class="summary-card">
        <span class="summary-icon primary"><el-icon><ShoppingCart /></el-icon></span>
        <div>
          <small>待买件数</small>
          <strong>{{ pendingItems.length }}<em>件</em></strong>
          <span class="summary-note">平均 ¥{{ money(averagePrice) }}</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon warning"><el-icon><Wallet /></el-icon></span>
        <div>
          <small>待买合计</small>
          <strong class="amount">¥{{ money(pendingTotal) }}</strong>
          <span class="summary-note">下单前再想一次是否真的需要</span>
        </div>
      </div>
      <div class="summary-card">
        <span class="summary-icon secondary"><el-icon><Check /></el-icon></span>
        <div>
          <small>已买合计</small>
          <strong class="amount">¥{{ money(boughtTotal) }}</strong>
          <span class="summary-note">共 {{ boughtItems.length }} 件</span>
        </div>
      </div>
    </div>

    <section class="quick-bar">
      <div class="quick-inputs">
        <el-input
          v-model="quickName"
          placeholder="快速添加：输入想买的东西，回车即可"
          clearable
          @keyup.enter="quickAdd"
        >
          <template #prefix><el-icon><ShoppingCart /></el-icon></template>
        </el-input>
        <el-input-number
          v-model="quickPrice"
          :min="0"
          :max="1000000"
          :precision="2"
          :controls="false"
          placeholder="价格"
          class="quick-price"
        />
        <el-button type="primary" :loading="quickAdding" @click="quickAdd">
          <el-icon><Plus /></el-icon>添加
        </el-button>
      </div>

      <div class="quick-filters">
        <el-radio-group v-model="filter">
          <el-radio-button value="all">全部 {{ items.length }}</el-radio-button>
          <el-radio-button value="pending">待买 {{ pendingItems.length }}</el-radio-button>
          <el-radio-button value="bought">已买 {{ boughtItems.length }}</el-radio-button>
        </el-radio-group>
        <el-select v-model="sortBy" class="sort-select">
          <el-option v-for="option in SOURCE_OPTIONS" :key="option.value" :label="option.label" :value="option.value" />
        </el-select>
        <el-input v-model="keyword" placeholder="搜索物品" clearable class="search-input" />
      </div>
    </section>

    <section v-loading="loading" class="panel">
      <div v-if="!loading && !visibleItems.length" class="empty-block">
        <span class="empty-icon"><el-icon><ShoppingCart /></el-icon></span>
        <strong>{{ items.length ? '没有符合条件的物品' : '清单还是空的' }}</strong>
        <p>{{ items.length ? '换个筛选条件试试' : '在上面输入框里敲一个名字就能加上' }}</p>
      </div>

      <div v-else class="item-list">
        <article
          v-for="item in visibleItems"
          :key="item.id"
          class="item-row"
          :class="{ 'is-bought': item.status === 'bought' }"
        >
          <el-checkbox
            :model-value="item.status === 'bought'"
            class="item-check"
            @change="toggleBought(item)"
          />

          <div class="item-main">
            <strong>{{ item.name }}</strong>
            <span>{{ item.status === 'bought' ? '已买到' : '等待下单' }} · 编号 #{{ item.id }}</span>
          </div>

          <strong class="item-price">¥{{ money(Number(item.price)) }}</strong>

          <el-tag size="small" :type="item.status === 'bought' ? 'success' : 'warning'" effect="light" round>
            {{ item.status === 'bought' ? '已买' : '待买' }}
          </el-tag>

          <span class="item-date">{{ dayjs(item.createdAt ?? Date.now()).format('MM-DD') }}</span>

          <div class="item-actions">
            <el-button text size="small" @click="openEdit(item)"><el-icon><Edit /></el-icon>编辑</el-button>
            <el-button text size="small" type="danger" @click="handleDelete(item)">
              <el-icon><Delete /></el-icon>删除
            </el-button>
          </div>
        </article>
      </div>
    </section>

    <ShoppingFormDialog v-model="dialogVisible" :item="editing" :saving="saving" @save="handleSave" />
  </section>
</template>

<style scoped lang="scss">
.shopping-page {
  display: grid;
  gap: 18px;
  animation: shopping-in 0.35s ease both;
}

@keyframes shopping-in {
  from {
    opacity: 0;
    transform: translateY(7px);
  }
}

.page-heading {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
  align-items: flex-end;
  justify-content: space-between;
}

.page-heading p {
  margin: 0 0 6px;
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.18em;
}

.page-heading h2 {
  margin: 0;
  color: var(--text-primary);
  font-size: 28px;
  letter-spacing: -0.04em;
}

.page-heading span {
  display: block;
  margin-top: 7px;
  color: var(--text-secondary);
  font-size: 13px;
}

.heading-actions {
  display: flex;
  gap: 10px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.summary-card {
  display: flex;
  min-height: 104px;
  align-items: center;
  gap: 14px;
  padding: 18px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.summary-icon {
  display: grid;
  width: 44px;
  height: 44px;
  flex: none;
  place-items: center;
  border-radius: 13px;
  font-size: 20px;
}

.summary-icon.primary {
  color: var(--primary);
  background: var(--primary-soft);
}

.summary-icon.secondary {
  color: var(--secondary);
  background: var(--secondary-soft);
}

.summary-icon.warning {
  color: var(--warning);
  background: color-mix(in srgb, var(--warning) 14%, transparent);
}

.summary-card small {
  display: block;
  margin-bottom: 6px;
  color: var(--text-secondary);
  font-size: 12px;
}

.summary-card strong {
  color: var(--text-primary);
  font-size: 24px;
  letter-spacing: -0.035em;
}

.summary-card strong em {
  margin-left: 2px;
  color: var(--text-secondary);
  font-size: 13px;
  font-style: normal;
}

.summary-card strong.amount {
  font-size: 22px;
}

.summary-note {
  display: block;
  margin-top: 5px;
  color: var(--text-secondary);
  font-size: 12px;
}

.quick-bar {
  display: grid;
  gap: 12px;
  padding: 14px 16px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
}

.quick-inputs {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 150px auto;
  gap: 10px;
}

.quick-price {
  width: 100%;
}

.quick-filters {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  justify-content: space-between;
}

.sort-select {
  width: 148px;
}

.search-input {
  width: 180px;
}

.panel {
  padding: 15px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.item-list {
  display: grid;
  gap: 9px;
}

.item-row {
  display: grid;
  grid-template-columns: 28px minmax(140px, 1fr) 110px 62px 56px auto;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
  transition: all 0.18s ease;
}

.item-row:hover {
  border-color: color-mix(in srgb, var(--primary) 25%, var(--border-color));
  background: color-mix(in srgb, var(--primary-soft) 30%, var(--surface));
}

.item-row.is-bought .item-main strong {
  color: var(--text-secondary);
  text-decoration: line-through;
}

.item-check {
  height: 20px;
}

.item-main {
  min-width: 0;
}

.item-main strong,
.item-main span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.item-main strong {
  color: var(--text-primary);
  font-size: 14px;
}

.item-main span {
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 12px;
}

.item-price {
  color: var(--text-primary);
  font-size: 15px;
  text-align: right;
}

.item-date {
  color: var(--text-secondary);
  font-size: 13px;
}

.item-actions {
  display: flex;
  justify-content: flex-end;
}

.empty-block {
  display: grid;
  place-items: center;
  align-content: center;
  gap: 9px;
  padding: 40px 20px;
  border: 1px dashed var(--border-soft);
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
  text-align: center;
}

.empty-icon {
  display: grid;
  width: 56px;
  height: 56px;
  place-items: center;
  border-radius: 18px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 25px;
}

.empty-block strong {
  color: var(--text-primary);
  font-size: 14px;
}

.empty-block p {
  margin: 0;
  color: var(--text-secondary);
  font-size: 12px;
}

@media (max-width: 1080px) {
  .summary-grid {
    grid-template-columns: 1fr;
  }

  .item-row {
    grid-template-columns: 28px minmax(110px, 1fr) 100px auto;
  }

  .item-date,
  .item-row :deep(.el-tag) {
    display: none;
  }
}

@media (max-width: 720px) {
  .quick-inputs {
    grid-template-columns: 1fr;
  }

  .sort-select,
  .search-input {
    width: 100%;
  }

  .item-row {
    grid-template-columns: 28px minmax(90px, 1fr) auto;
  }

  .item-price {
    text-align: left;
  }

  .item-actions {
    grid-column: span 3;
    justify-content: flex-end;
  }
}
</style>

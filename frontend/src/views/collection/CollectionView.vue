<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Collection as CollectionIcon,
  Delete,
  Edit,
  Grid,
  List,
  Plus,
  Search,
  TrendCharts,
} from '@element-plus/icons-vue'
import {
  createCollection,
  deleteCollection,
  getCollectionStats,
  getCollectionYears,
  listCollection,
  updateCollection,
} from '@/api/collection'
import CollectionCard from './components/CollectionCard.vue'
import CollectionFormDialog from './components/CollectionFormDialog.vue'
import {
  COLLECTION_TYPE_META,
  SORT_OPTIONS,
  STATUS_ORDER,
  nextStatus,
  statusLabel,
  typeMeta,
} from './collection-meta'
import type {
  CollectionItem,
  CollectionPayload,
  CollectionStats,
  CollectionStatus,
  CollectionType,
} from '@/types'

const VIEW_KEY = 'life-workbench-collection-view'
const PAGE_SIZE = 24

const items = ref<CollectionItem[]>([])
const total = ref(0)
const page = ref(1)
const loading = ref(false)
const saving = ref(false)

const stats = ref<CollectionStats | null>(null)
const statsYear = ref(new Date().getFullYear())
const years = ref<number[]>([new Date().getFullYear()])

const typeFilter = ref<CollectionType | ''>('')
const statusFilter = ref<CollectionStatus | ''>('')
const sortBy = ref<(typeof SORT_OPTIONS)[number]['value']>('createdAt')
const keyword = ref('')

const viewMode = ref<'wall' | 'list'>(
  localStorage.getItem(VIEW_KEY) === 'list' ? 'list' : 'wall',
)

const dialogVisible = ref(false)
const editingItem = ref<CollectionItem | null>(null)

let keywordTimer: ReturnType<typeof setTimeout> | null = null

const lifetime = computed(
  () => stats.value?.lifetime ?? { total: 0, finished: 0, wish: 0, doing: 0, ratingAverage: null },
)
const ratingText = computed(() => {
  const value = stats.value?.ratingAverage
  return value === null || value === undefined ? '暂无评分' : value.toFixed(1)
})
const isCurrentYear = computed(() => statsYear.value === new Date().getFullYear())
const yearStatLabel = computed(() => (isCurrentYear.value ? '本年收藏' : '当年收藏'))
const statusOptions = computed(() =>
  STATUS_ORDER.map((status) => ({
    value: status,
    label: statusLabel(status, typeFilter.value || 'book'),
  })),
)

const loadItems = async () => {
  loading.value = true
  try {
    const result = await listCollection({
      type: typeFilter.value || undefined,
      status: statusFilter.value || undefined,
      keyword: keyword.value.trim() || undefined,
      sortBy: sortBy.value,
      page: page.value,
      pageSize: PAGE_SIZE,
    })
    items.value = result.items
    total.value = result.total
  } finally {
    loading.value = false
  }
}

const loadStats = async () => {
  stats.value = await getCollectionStats(statsYear.value)
}

const loadYears = async () => {
  const result = await getCollectionYears()
  years.value = result.length ? result : [new Date().getFullYear()]
}

const refresh = async () => {
  await Promise.all([loadItems(), loadStats()])
}

const openCreate = () => {
  editingItem.value = null
  dialogVisible.value = true
}

const openEdit = (item: CollectionItem) => {
  editingItem.value = item
  dialogVisible.value = true
}

const handleSave = async (payload: CollectionPayload) => {
  saving.value = true
  try {
    if (editingItem.value) await updateCollection(editingItem.value.id, payload)
    else await createCollection(payload)
    ElMessage.success(editingItem.value ? '收藏已更新' : '已加入收藏')
    dialogVisible.value = false
    await Promise.all([refresh(), loadYears()])
  } finally {
    saving.value = false
  }
}

const handleDelete = async (item: CollectionItem) => {
  await ElMessageBox.confirm(`确定删除《${item.title}》吗？`, '删除收藏', {
    type: 'warning',
    confirmButtonText: '删除',
    cancelButtonText: '取消',
  })
  await deleteCollection(item.id)
  ElMessage.success('收藏已删除')
  if (items.value.length === 1 && page.value > 1) page.value -= 1
  await refresh()
}

const changeStatus = async (item: CollectionItem, value: unknown) => {
  const status = value as CollectionStatus
  if (!status || status === item.status) return
  const updated = await updateCollection(item.id, { status })
  item.status = updated.status
  ElMessage.success(`已标记为「${statusLabel(updated.status, updated.type)}」`)
  await loadStats()
}

const handleCycleStatus = async (item: CollectionItem) => {
  await changeStatus(item, nextStatus(item.status))
}

watch([typeFilter, statusFilter, sortBy], () => {
  page.value = 1
  void loadItems()
})

watch(page, () => void loadItems())

watch(statsYear, () => void loadStats())

watch(viewMode, (value) => localStorage.setItem(VIEW_KEY, value))

watch(keyword, () => {
  if (keywordTimer) clearTimeout(keywordTimer)
  keywordTimer = setTimeout(() => {
    page.value = 1
    void loadItems()
  }, 320)
})

onMounted(async () => {
  await Promise.all([refresh(), loadYears()])
})

onBeforeUnmount(() => {
  if (keywordTimer) clearTimeout(keywordTimer)
})
</script>

<template>
  <section class="collection-page">
    <header class="page-heading">
      <p>MEDIA COLLECTION</p>
      <h2>书影音收藏</h2>
      <span>读过、看过、听过的东西，都值得留个位置。</span>
    </header>

    <section class="stats-card">
      <div class="stats-head">
        <div class="stats-title">
          <span class="stats-icon"><el-icon><TrendCharts /></el-icon></span>
          <div>
            <strong>年度统计</strong>
            <small>{{ stats?.year }} 年新增收藏概览</small>
          </div>
        </div>
        <el-select v-model="statsYear" size="small" class="year-select">
          <el-option v-for="year in years" :key="year" :label="`${year} 年`" :value="year" />
        </el-select>
      </div>

      <div class="stats-grid">
        <div class="stat">
          <strong>{{ stats?.total ?? 0 }}</strong>
          <small>{{ yearStatLabel }}</small>
        </div>
        <div class="stat">
          <strong class="tone-green">{{ stats?.finished ?? 0 }}</strong>
          <small>已完成</small>
        </div>
        <div class="stat">
          <strong class="tone-blue">{{ stats?.books ?? 0 }}</strong>
          <small>书籍</small>
        </div>
        <div class="stat">
          <strong class="tone-violet">{{ stats?.movies ?? 0 }}</strong>
          <small>影视</small>
        </div>
        <div class="stat">
          <strong class="tone-teal">{{ stats?.music ?? 0 }}</strong>
          <small>音乐</small>
        </div>
      </div>

      <p class="stats-foot">
        累计 {{ lifetime.total }} 条 · 想读想看想听 {{ lifetime.wish }} 条 · 进行中 {{ lifetime.doing }} 条 ·
        平均评分 {{ ratingText }}
      </p>
    </section>

    <section class="filter-bar">
      <div class="filter-left">
        <el-radio-group v-model="typeFilter" class="type-tabs">
          <el-radio-button value="">全部</el-radio-button>
          <el-radio-button v-for="meta in COLLECTION_TYPE_META" :key="meta.value" :value="meta.value">
            {{ meta.label }}
          </el-radio-button>
        </el-radio-group>

        <el-select v-model="statusFilter" placeholder="全部状态" clearable class="filter-select">
          <el-option label="全部状态" value="" />
          <el-option
            v-for="option in statusOptions"
            :key="option.value"
            :label="option.label"
            :value="option.value"
          />
        </el-select>

        <el-select v-model="sortBy" class="filter-select">
          <el-option v-for="option in SORT_OPTIONS" :key="option.value" :label="option.label" :value="option.value" />
        </el-select>

        <el-input v-model="keyword" placeholder="搜索标题或短评" clearable class="search-input">
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>
      </div>

      <div class="filter-right">
        <el-radio-group v-model="viewMode" class="view-switch">
          <el-radio-button value="wall"><el-icon><Grid /></el-icon></el-radio-button>
          <el-radio-button value="list"><el-icon><List /></el-icon></el-radio-button>
        </el-radio-group>
        <el-button type="primary" @click="openCreate">
          <el-icon><Plus /></el-icon>新增收藏
        </el-button>
      </div>
    </section>

    <div v-if="!loading && !items.length" class="empty-collection">
      <span class="empty-icon"><el-icon><CollectionIcon /></el-icon></span>
      <strong>{{ keyword || typeFilter || statusFilter ? '没有符合条件的收藏' : '还没有收藏，先添加一本想读的书吧' }}</strong>
      <p>点击右上角「新增收藏」记录书籍、影视或音乐</p>
      <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon>新增收藏</el-button>
    </div>

    <section v-else-if="viewMode === 'wall'" v-loading="loading" class="cover-wall">
      <CollectionCard
        v-for="item in items"
        :key="item.id"
        :item="item"
        @edit="openEdit(item)"
        @remove="handleDelete(item)"
        @cycle-status="handleCycleStatus(item)"
      />
    </section>

    <section v-else v-loading="loading" class="record-card">
      <div class="record-list">
        <article v-for="item in items" :key="item.id" class="record-row">
          <span class="thumb" :class="typeMeta(item.type).tone">
            <el-image v-if="item.coverUrl" :src="item.coverUrl" fit="cover" class="thumb-image">
              <template #error>
                <el-icon><component :is="typeMeta(item.type).icon" /></el-icon>
              </template>
            </el-image>
            <el-icon v-else><component :is="typeMeta(item.type).icon" /></el-icon>
          </span>

          <div class="record-main">
            <strong>{{ item.title }}</strong>
            <span>{{ item.comment || '暂无短评' }}</span>
          </div>

          <span class="type-text">{{ typeMeta(item.type).label }}</span>

          <el-select
            :model-value="item.status"
            size="small"
            class="status-select"
            @change="changeStatus(item, $event)"
          >
            <el-option
              v-for="status in STATUS_ORDER"
              :key="status"
              :label="statusLabel(status, item.type)"
              :value="status"
            />
          </el-select>

          <el-rate :model-value="item.rating ?? 0" disabled size="small" class="record-rate" />

          <span class="record-year">{{ item.year ?? '—' }}</span>

          <div class="record-actions">
            <el-button text size="small" @click="openEdit(item)"><el-icon><Edit /></el-icon>编辑</el-button>
            <el-button text size="small" type="danger" @click="handleDelete(item)">
              <el-icon><Delete /></el-icon>删除
            </el-button>
          </div>
        </article>
      </div>
    </section>

    <div v-if="total > PAGE_SIZE" class="pagination-wrap">
      <el-pagination
        v-model:current-page="page"
        :page-size="PAGE_SIZE"
        :total="total"
        layout="prev, pager, next"
        background
      />
    </div>

    <CollectionFormDialog
      v-model="dialogVisible"
      :item="editingItem"
      :saving="saving"
      @save="handleSave"
    />
  </section>
</template>

<style scoped lang="scss">
.collection-page {
  display: grid;
  gap: 18px;
  animation: collection-in 0.35s ease both;
}

@keyframes collection-in {
  from {
    opacity: 0;
    transform: translateY(7px);
  }
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

.stats-card {
  padding: 18px 20px 16px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.stats-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}

.stats-title {
  display: flex;
  align-items: center;
  gap: 11px;
}

.stats-icon {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 12px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 18px;
}

.stats-title strong,
.stats-title small {
  display: block;
}

.stats-title strong {
  color: var(--text-primary);
  font-size: 15px;
}

.stats-title small {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.year-select {
  width: 118px;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 12px;
}

.stat {
  padding: 13px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
}

.stat strong {
  display: block;
  color: var(--text-primary);
  font-size: 23px;
  letter-spacing: -0.03em;
}

.stat small {
  display: block;
  margin-top: 5px;
  color: var(--text-secondary);
  font-size: 12px;
}

.tone-blue {
  color: var(--primary) !important;
}

.tone-violet {
  color: var(--accent) !important;
}

.tone-green {
  color: var(--secondary) !important;
}

.tone-teal {
  color: #22d3ee !important;
}

.stats-foot {
  margin: 14px 0 0;
  color: var(--text-secondary);
  font-size: 13px;
}

.filter-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
}

.filter-left,
.filter-right {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
}

.filter-select {
  width: 132px;
}

.search-input {
  width: 190px;
}

.view-switch :deep(.el-radio-button__inner) {
  padding: 8px 11px;
}

.cover-wall {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(158px, 1fr));
  gap: 16px;
  min-height: 200px;
}

.record-card {
  min-height: 240px;
  padding: 15px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.record-list {
  display: grid;
  gap: 9px;
}

.record-row {
  display: grid;
  grid-template-columns: 46px minmax(140px, 1fr) 60px 110px 108px 62px auto;
  align-items: center;
  gap: 12px;
  padding: 11px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
  transition: all 0.18s ease;
}

.record-row:hover {
  border-color: color-mix(in srgb, var(--primary) 25%, var(--border-color));
  background: color-mix(in srgb, var(--primary-soft) 30%, var(--surface));
}

.thumb {
  display: grid;
  width: 42px;
  height: 56px;
  overflow: hidden;
  place-items: center;
  border-radius: 9px;
  color: #fff;
  font-size: 18px;
}

.thumb.blue {
  background: var(--primary);
}

.thumb.violet {
  background: var(--accent);
}

.thumb.green {
  background: var(--secondary);
}

.thumb-image {
  width: 100%;
  height: 100%;
}

.record-main {
  min-width: 0;
}

.record-main strong,
.record-main span {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.record-main strong {
  color: var(--text-primary);
  font-size: 14px;
}

.record-main span {
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 12px;
}

.type-text {
  color: var(--text-regular);
  font-size: 13px;
}

.status-select {
  width: 100%;
}

.record-rate :deep(.el-rate__icon) {
  margin-right: 1px;
  font-size: 14px;
}

.record-year {
  color: var(--text-secondary);
  font-size: 13px;
}

.record-actions {
  display: flex;
  justify-content: flex-end;
}

.empty-collection {
  display: grid;
  min-height: 300px;
  place-items: center;
  align-content: center;
  gap: 10px;
  padding: 30px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  text-align: center;
}

.empty-icon {
  display: grid;
  width: 62px;
  height: 62px;
  place-items: center;
  border: 1px dashed color-mix(in srgb, var(--primary) 30%, var(--border-color));
  border-radius: 20px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 26px;
}

.empty-collection strong {
  color: var(--text-primary);
  font-size: 14px;
}

.empty-collection p {
  margin: 0 0 6px;
  color: var(--text-secondary);
  font-size: 12px;
}

.pagination-wrap {
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 1080px) {
  .stats-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .record-row {
    grid-template-columns: 46px minmax(120px, 1fr) 100px 100px auto;
  }

  .type-text,
  .record-year {
    display: none;
  }

  .record-rate {
    display: none;
  }
}

@media (max-width: 760px) {
  .stats-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .filter-select,
  .search-input {
    width: 100%;
  }

  .filter-left,
  .filter-right {
    width: 100%;
  }

  .cover-wall {
    grid-template-columns: repeat(auto-fill, minmax(136px, 1fr));
  }

  .record-row {
    grid-template-columns: 46px minmax(90px, 1fr) auto;
  }

  .status-select {
    grid-column: span 2;
  }

  .record-actions {
    grid-column: span 3;
    justify-content: flex-end;
  }
}
</style>

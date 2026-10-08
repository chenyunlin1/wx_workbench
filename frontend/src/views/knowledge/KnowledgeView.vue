<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage, type UploadFile } from 'element-plus'
import { Check, DataAnalysis, Plus, Search, Upload } from '@element-plus/icons-vue'
import {
  createKnowledge,
  exportKnowledgeCsv,
  getKnowledgeDetail,
  getKnowledgeTags,
  importKnowledgeCsv,
  listKnowledge,
  toggleKnowledgeLearned,
} from '@/api/knowledge'
import KnowledgeCard from './components/KnowledgeCard.vue'
import NoteEditorDialog from './components/NoteEditorDialog.vue'
import TagCloud from './components/TagCloud.vue'
import type { KnowledgeItem, KnowledgePayload, KnowledgeSortBy, KnowledgeType } from '@/types'

const route = useRoute()

const FIXED_TAGS = ['Vue3', 'React', 'TypeScript', 'JavaScript', 'CSS/SCSS', 'HTML5', 'Vite', 'Pinia', 'Element Plus', 'NestJS', 'Node.js', 'TypeORM', 'MySQL', 'Redis', 'Docker', '微服务', '前端工程化', '性能优化']
const items = ref<KnowledgeItem[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const loading = ref(false)
const finished = ref(false)
const keyword = ref('')
const typeFilter = ref<KnowledgeType | ''>('')
const sortBy = ref<KnowledgeSortBy>('updatedAt')
const selectedTag = ref('')
const selectedIds = ref<number[]>([])
const tags = ref([...FIXED_TAGS])
const noteDialogVisible = ref(false)
const importDialogVisible = ref(false)
const statsDialogVisible = ref(false)
const detailDialogVisible = ref(false)
const submitting = ref(false)
const importing = ref(false)
const importFile = ref<File | null>(null)
const detailItem = ref<KnowledgeItem | null>(null)

const stats = computed(() => ({
  total: total.value,
  notes: items.value.filter((item) => item.type === 'note').length,
  qa: items.value.filter((item) => item.type === 'qa').length,
  learned: items.value.filter((item) => item.isLearned).length,
  views: items.value.reduce((sum, item) => sum + Number(item.views ?? 0), 0),
}))
const allSelected = computed(() => items.value.length > 0 && items.value.every((item) => selectedIds.value.includes(item.id)))

const fetchPage = async (targetPage: number, reset = false) => {
  if (loading.value) return
  loading.value = true
  try {
    const result = await listKnowledge({ keyword: keyword.value.trim() || undefined, type: typeFilter.value || undefined, tag: selectedTag.value || undefined, sortBy: sortBy.value, page: targetPage, pageSize: pageSize.value })
    items.value = reset ? result.items : [...items.value, ...result.items]
    total.value = result.total
    page.value = targetPage + 1
    finished.value = result.items.length < pageSize.value || items.value.length >= result.total
  } finally {
    loading.value = false
  }
}

const loadFirstPage = async () => {
  page.value = 1
  finished.value = false
  items.value = []
  selectedIds.value = []
  await fetchPage(1, true)
}

const loadMore = async () => {
  if (!loading.value && !finished.value) await fetchPage(page.value)
}

const loadTags = async () => {
  const usedTags = await getKnowledgeTags()
  tags.value = [...new Set([...FIXED_TAGS, ...usedTags])]
}

const runQuery = () => loadFirstPage()
const handleTagChange = async (tag: string) => { selectedTag.value = selectedTag.value === tag ? '' : tag; await loadFirstPage() }
const showNotes = async () => { typeFilter.value = typeFilter.value === 'note' ? '' : 'note'; await loadFirstPage() }
const handleSelect = (id: number, checked: boolean) => { selectedIds.value = checked ? [...new Set([...selectedIds.value, id])] : selectedIds.value.filter((itemId) => itemId !== id) }
const handleSelectAll = (checked: boolean) => { selectedIds.value = checked ? items.value.map((item) => item.id) : [] }
const handleSelectAllChange = (value: string | number | boolean) => handleSelectAll(Boolean(value))

const handleToggleLearned = async (item: KnowledgeItem) => {
  const previous = item.isLearned
  item.isLearned = !previous
  try {
    Object.assign(item, await toggleKnowledgeLearned(item.id, item.isLearned))
    ElMessage.success(item.isLearned ? '已标记为已学习' : '已取消学习标记')
  } catch { item.isLearned = previous }
}

const batchCheckIn = async () => {
  const targets = items.value.filter((item) => selectedIds.value.includes(item.id) && !item.isLearned)
  if (!targets.length) { ElMessage.info(selectedIds.value.length ? '所选内容均已学习' : '请先选择要打卡的内容'); return }
  await Promise.all(targets.map((item) => toggleKnowledgeLearned(item.id, true)))
  targets.forEach((item) => (item.isLearned = true))
  ElMessage.success(`已完成 ${targets.length} 条学习打卡`)
}

const openDetail = async (item: KnowledgeItem) => {
  detailItem.value = await getKnowledgeDetail(item.id)
  const current = items.value.find((entry) => entry.id === item.id)
  if (current) current.views = detailItem.value.views
  detailDialogVisible.value = true
}

const createNote = async (payload: KnowledgePayload & { type: KnowledgeType; title: string; content: string }) => {
  submitting.value = true
  try {
    await createKnowledge(payload)
    noteDialogVisible.value = false
    ElMessage.success('知识笔记已保存')
    await Promise.all([loadFirstPage(), loadTags()])
  } finally { submitting.value = false }
}

const handleImportFile = (uploadFile: UploadFile) => { importFile.value = uploadFile.raw ?? null }
const handleImportRemove = () => { importFile.value = null }
const submitImport = async () => {
  if (!importFile.value) { ElMessage.warning('请先选择 CSV 文件'); return }
  importing.value = true
  try {
    const result = await importKnowledgeCsv(importFile.value)
    ElMessage.success(`导入完成：成功 ${result.imported} 条，跳过 ${result.skipped} 条`)
    importDialogVisible.value = false
    importFile.value = null
    await Promise.all([loadFirstPage(), loadTags()])
  } finally { importing.value = false }
}

const downloadCsv = async () => {
  const blob = await exportKnowledgeCsv({ keyword: keyword.value.trim() || undefined, type: typeFilter.value || undefined, tag: selectedTag.value || undefined, sortBy: sortBy.value })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = `knowledge-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  const routeKeyword = route.query.keyword
  if (typeof routeKeyword === 'string' && routeKeyword) keyword.value = routeKeyword
  await Promise.all([loadFirstPage(), loadTags()])
})
</script>
<template>
  <section class="knowledge-page">
    <header class="page-toolbar">
      <div>
        <p>KNOWLEDGE BASE</p>
        <h2>学习知识库</h2>
      </div>
      <div class="toolbar-actions">
        <el-button @click="showNotes">笔记</el-button>
        <el-button @click="statsDialogVisible = true">统计报告</el-button>
        <el-button @click="importDialogVisible = true">导入 CSV</el-button>
        <el-button @click="downloadCsv">导出 CSV</el-button>
        <el-button @click="batchCheckIn"><el-icon><Check /></el-icon>打卡</el-button>
        <el-button type="primary" @click="noteDialogVisible = true"><el-icon><Plus /></el-icon>记笔记</el-button>
      </div>
    </header>

    <section class="filter-card">
      <div class="filter-row">
        <el-input v-model="keyword" class="keyword-input" clearable placeholder="搜索标题/内容关键字" @keyup.enter="runQuery">
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>
        <el-select v-model="typeFilter" class="type-select" placeholder="全部类型" clearable>
          <el-option label="全部类型" value="" />
          <el-option label="笔记" value="note" />
          <el-option label="问答" value="qa" />
          <el-option label="前端" value="前端" disabled />
          <el-option label="后端" value="后端" disabled />
          <el-option label="全栈" value="全栈" disabled />
          <el-option label="算法" value="算法" disabled />
          <el-option label="运维" value="运维" disabled />
        </el-select>
        <el-select v-model="sortBy" class="sort-select">
          <el-option label="更新时间 ↓" value="updatedAt" />
          <el-option label="创建时间" value="createdAt" />
          <el-option label="点击量" value="views" />
        </el-select>
        <el-select v-model="pageSize" class="page-size-select" @change="loadFirstPage">
          <el-option label="10 条/页" :value="10" />
          <el-option label="20 条/页" :value="20" />
          <el-option label="50 条/页" :value="50" />
          <el-option label="100 条/页" :value="100" />
        </el-select>
        <el-button type="primary" @click="runQuery"><el-icon><Search /></el-icon>查询</el-button>
        <el-button>筛选 ▼</el-button>
      </div>
      <div class="filter-summary">
        <span>共 {{ total }} 条，滚动到底部自动加载</span>
        <div v-if="selectedTag || typeFilter" class="active-filters">
          <el-tag v-if="selectedTag" closable @close="handleTagChange(selectedTag)">{{ selectedTag }}</el-tag>
          <el-tag v-if="typeFilter" closable @close="typeFilter = ''; loadFirstPage()">{{ typeFilter === 'note' ? '笔记' : '问答' }}</el-tag>
        </div>
      </div>
    </section>

    <TagCloud :tags="tags" :selected="selectedTag" @update:selected="handleTagChange" />

    <div class="list-toolbar">
      <el-checkbox :model-value="allSelected" @change="handleSelectAllChange">全选当前页</el-checkbox>
      <span v-if="selectedIds.length">已选择 {{ selectedIds.length }} 条</span>
      <span v-else>点击标题查看完整内容</span>
    </div>

    <div v-infinite-scroll="loadMore" class="knowledge-list" :infinite-scroll-disabled="loading || finished" :infinite-scroll-distance="160">
      <KnowledgeCard
        v-for="item in items"
        :key="item.id"
        :item="item"
        :selected="selectedIds.includes(item.id)"
        @select="handleSelect"
        @toggle-learned="handleToggleLearned"
        @open="openDetail"
      />
      <el-empty v-if="!loading && !items.length" description="没有匹配的知识内容" />
      <div v-if="loading" class="list-status"><el-icon class="is-loading"><DataAnalysis /></el-icon>正在加载知识卡片…</div>
      <div v-else-if="finished && items.length" class="list-status">已经到底了 · 共 {{ total }} 条</div>
    </div>

    <NoteEditorDialog v-model="noteDialogVisible" :tag-options="tags" :loading="submitting" @submit="createNote" />

    <el-dialog v-model="importDialogVisible" title="导入 CSV" width="min(92vw, 560px)" append-to-body>
      <el-upload drag action="#" accept=".csv,text/csv" :auto-upload="false" :limit="1" :on-change="handleImportFile" :on-remove="handleImportRemove">
        <el-icon class="upload-icon"><Upload /></el-icon>
        <div class="el-upload__text">拖拽 CSV 文件到此处，或 <em>点击选择</em></div>
        <template #tip><div class="el-upload__tip">支持 UTF-8 CSV，表头可使用 type/title/content/tags 或类型/标题/内容/标签。</div></template>
      </el-upload>
      <template #footer>
        <el-button @click="importDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="importing" @click="submitImport">开始导入</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="statsDialogVisible" title="学习统计报告" width="min(92vw, 620px)" append-to-body>
      <div class="stats-grid">
        <div><span>知识总量</span><strong>{{ stats.total }}</strong></div>
        <div><span>笔记数量</span><strong>{{ stats.notes }}</strong></div>
        <div><span>问答数量</span><strong>{{ stats.qa }}</strong></div>
        <div><span>已学习</span><strong>{{ stats.learned }}</strong></div>
        <div><span>当前页点击量</span><strong>{{ stats.views }}</strong></div>
      </div>
    </el-dialog>

    <el-dialog v-model="detailDialogVisible" title="知识详情" width="min(92vw, 760px)" append-to-body>
      <div v-if="detailItem" class="detail-content">
        <div class="detail-meta">
          <el-tag :type="detailItem.type === 'note' ? 'primary' : 'warning'" effect="light">{{ detailItem.type === 'note' ? '✨ 笔记' : '❓ 问答' }}</el-tag>
          <span>{{ detailItem.views }} 次点击</span>
          <span>{{ new Date(detailItem.updatedAt).toLocaleDateString('zh-CN') }}</span>
        </div>
        <h3>{{ detailItem.title }}</h3>
        <div class="detail-text">{{ detailItem.content }}</div>
        <div class="detail-tags"><el-tag v-for="tag in detailItem.tags" :key="tag" effect="light" round>{{ tag }}</el-tag></div>
      </div>
    </el-dialog>
  </section>
</template>
<style scoped lang="scss">
.knowledge-page { display: grid; grid-template-columns: minmax(0, 1fr); gap: 17px; animation: knowledge-in 0.35s ease both; }
@keyframes knowledge-in { from { opacity: 0; transform: translateY(7px); } }
.page-toolbar { display: flex; align-items: flex-end; justify-content: space-between; gap: 18px; }
.page-toolbar p { margin: 0 0 5px; color: var(--primary); font-size: 12px; font-weight: 800; letter-spacing: 0.18em; }
.page-toolbar h2 { margin: 0; color: var(--text-primary); font-size: 28px; letter-spacing: -0.04em; }
.toolbar-actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
.filter-card { padding: 16px 18px 13px; border: 1px solid var(--border-soft); border-radius: var(--radius-md); background: var(--surface-raised); box-shadow: var(--shadow-sm); }
.filter-row { display: flex; align-items: center; gap: 10px; }
.keyword-input { width: 40%; min-width: 230px; }
.type-select { width: 145px; }
.sort-select { width: 135px; }
.page-size-select { width: 115px; }
.filter-summary { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding-top: 11px; color: var(--text-secondary); font-size: 12px; }
.active-filters { display: flex; gap: 6px; }
.list-toolbar { display: flex; align-items: center; justify-content: space-between; padding: 0 3px; color: var(--text-secondary); font-size: 12px; }
.knowledge-list { display: grid; grid-template-columns: minmax(0, 1fr); max-height: 62vh; gap: 12px; padding: 1px 3px 18px; overflow-y: auto; scroll-behavior: smooth; }
.list-status { display: flex; align-items: center; justify-content: center; gap: 7px; padding: 14px; color: var(--text-secondary); font-size: 12px; }
.upload-icon { margin-bottom: 9px; color: var(--primary); font-size: 32px; }
.stats-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 11px; }
.stats-grid > div { padding: 17px; border: 1px solid var(--border-soft); border-radius: 13px; background: var(--surface-muted); }
.stats-grid span, .stats-grid strong { display: block; }
.stats-grid span { color: var(--text-secondary); font-size: 12px; }
.stats-grid strong { margin-top: 7px; color: var(--primary); font-size: 25px; }
.detail-meta, .detail-tags { display: flex; align-items: center; flex-wrap: wrap; gap: 9px; }
.detail-meta > span { color: var(--text-secondary); font-size: 12px; }
.detail-content h3 { margin: 17px 0 12px; color: var(--text-primary); font-size: 21px; line-height: 1.5; }
.detail-text { padding: 16px; border: 1px solid var(--border-soft); border-radius: 12px; color: var(--text-regular); background: var(--surface-muted); font-size: 14px; line-height: 1.9; white-space: pre-wrap; }
.detail-tags { margin-top: 15px; }
@media (max-width: 1080px) {
  .page-toolbar { align-items: flex-start; flex-direction: column; }
  .toolbar-actions { justify-content: flex-start; }
  .filter-row { flex-wrap: wrap; }
  .keyword-input { width: 100%; }
}
@media (max-width: 620px) {
  .page-toolbar h2 { font-size: 23px; }
  .toolbar-actions :deep(.el-button) { margin-left: 0; }
  .type-select, .sort-select, .page-size-select { width: calc(50% - 5px); }
  .stats-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .knowledge-list { max-height: none; }
  .filter-summary { align-items: flex-start; flex-direction: column; }
}
</style>
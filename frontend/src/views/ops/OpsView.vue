<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import dayjs from 'dayjs'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Check, CopyDocument, Delete, Edit, Monitor, Plus, Search } from '@element-plus/icons-vue'
import { createOpsCommand, deleteOpsCommand, listOpsCommands, updateOpsCommand } from '@/api/ops'
import OpsCommandFormDialog from './components/OpsCommandFormDialog.vue'
import type { OpsCommand, OpsCommandPayload } from '@/types'

const CATEGORY_ORDER = ['Linux', 'systemd', 'MySQL', 'Nginx', '部署', '网络', '其他']

const items = ref<OpsCommand[]>([])
const loading = ref(false)
const saving = ref(false)
const keyword = ref('')
const activeCategory = ref('全部')
const copiedId = ref<number | null>(null)
const dialogVisible = ref(false)
const editing = ref<OpsCommand | null>(null)

const categories = computed(() => {
  const counts = new Map<string, number>()
  for (const item of items.value) counts.set(item.category, (counts.get(item.category) ?? 0) + 1)
  const fallbackIndex = (name: string) => {
    const index = CATEGORY_ORDER.indexOf(name)
    return index === -1 ? CATEGORY_ORDER.length : index
  }
  return [...counts.entries()]
    .sort(([a], [b]) => fallbackIndex(a) - fallbackIndex(b) || a.localeCompare(b))
    .map(([name, count]) => ({ name, count }))
})

const visibleItems = computed(() => {
  const kw = keyword.value.trim().toLowerCase()
  return items.value.filter((item) => {
    if (activeCategory.value !== '全部' && item.category !== activeCategory.value) return false
    if (!kw) return true
    return [item.title, item.command, item.description ?? '', item.category].some(
      (field) => field.toLowerCase().includes(kw),
    )
  })
})

const load = async () => {
  loading.value = true
  try {
    items.value = await listOpsCommands()
  } finally {
    loading.value = false
  }
}

const copyText = async (text: string) => {
  // http 直连属于非安全上下文，navigator.clipboard 不存在，需要退回 execCommand
  if (navigator.clipboard && window.isSecureContext) {
    try {
      await navigator.clipboard.writeText(text)
      return true
    } catch {
      /* 走下面的兜底 */
    }
  }
  const textarea = document.createElement('textarea')
  textarea.value = text
  textarea.setAttribute('readonly', '')
  textarea.style.position = 'fixed'
  textarea.style.top = '-9999px'
  document.body.appendChild(textarea)
  textarea.select()
  let ok = false
  try {
    ok = document.execCommand('copy')
  } catch {
    ok = false
  }
  document.body.removeChild(textarea)
  return ok
}

const handleCopy = async (item: OpsCommand) => {
  const ok = await copyText(item.command)
  if (!ok) {
    ElMessage.warning('复制失败，请手动选中复制')
    return
  }
  copiedId.value = item.id
  window.setTimeout(() => {
    if (copiedId.value === item.id) copiedId.value = null
  }, 1500)
}

const openCreate = () => {
  editing.value = null
  dialogVisible.value = true
}

const openEdit = (item: OpsCommand) => {
  editing.value = item
  dialogVisible.value = true
}

const handleSave = async (payload: OpsCommandPayload) => {
  saving.value = true
  try {
    if (editing.value) await updateOpsCommand(editing.value.id, payload)
    else await createOpsCommand(payload)
    ElMessage.success(editing.value ? '命令已更新' : '命令已添加')
    dialogVisible.value = false
    await load()
  } finally {
    saving.value = false
  }
}

const handleDelete = async (item: OpsCommand) => {
  await ElMessageBox.confirm(`确定删除「${item.title}」吗？`, '删除命令', {
    type: 'warning',
    confirmButtonText: '删除',
    cancelButtonText: '取消',
  })
  await deleteOpsCommand(item.id)
  ElMessage.success('已删除')
  await load()
}

onMounted(load)
</script>

<template>
  <section class="ops-page">
    <header class="page-heading">
      <div>
        <p>OPS CHEATSHEET</p>
        <h2>运维速查</h2>
        <span>常用运维命令收在这里，搜一下、复制一下就能用。</span>
      </div>
      <div class="heading-actions">
        <el-button type="primary" @click="openCreate"><el-icon><Plus /></el-icon>新增命令</el-button>
      </div>
    </header>

    <section class="ops-toolbar">
      <el-input v-model="keyword" placeholder="搜索命令、说明或分类" clearable class="ops-search">
        <template #prefix><el-icon><Search /></el-icon></template>
      </el-input>

      <div class="category-chips">
        <button
          type="button"
          class="chip"
          :class="{ active: activeCategory === '全部' }"
          @click="activeCategory = '全部'"
        >
          全部 <em>{{ items.length }}</em>
        </button>
        <button
          v-for="category in categories"
          :key="category.name"
          type="button"
          class="chip"
          :class="{ active: activeCategory === category.name }"
          @click="activeCategory = category.name"
        >
          {{ category.name }} <em>{{ category.count }}</em>
        </button>
      </div>
    </section>

    <section v-loading="loading" class="ops-panel">
      <div v-if="!loading && !visibleItems.length" class="empty-block">
        <span class="empty-icon"><el-icon><Monitor /></el-icon></span>
        <strong>{{ items.length ? '没有匹配的命令' : '还没有命令' }}</strong>
        <p>{{ items.length ? '换个关键词或分类试试' : '点右上角「新增命令」，把常用命令记进来' }}</p>
      </div>

      <div v-else class="command-grid">
        <article v-for="item in visibleItems" :key="item.id" class="command-card">
          <div class="card-head">
            <strong :title="item.title">{{ item.title }}</strong>
            <el-tag size="small" round effect="light">{{ item.category }}</el-tag>
          </div>

          <div class="command-box">
            <code>{{ item.command }}</code>
            <button
              type="button"
              class="copy-btn"
              :class="{ copied: copiedId === item.id }"
              @click="handleCopy(item)"
            >
              <el-icon><Check v-if="copiedId === item.id" /><CopyDocument v-else /></el-icon>
              {{ copiedId === item.id ? '已复制' : '复制' }}
            </button>
          </div>

          <p v-if="item.description" class="command-desc">{{ item.description }}</p>

          <div class="card-foot">
            <span>更新 {{ dayjs(item.updatedAt).format('MM-DD HH:mm') }}</span>
            <div class="card-actions">
              <el-button text size="small" @click="openEdit(item)"><el-icon><Edit /></el-icon>编辑</el-button>
              <el-button text size="small" type="danger" @click="handleDelete(item)">
                <el-icon><Delete /></el-icon>删除
              </el-button>
            </div>
          </div>
        </article>
      </div>
    </section>

    <OpsCommandFormDialog v-model="dialogVisible" :item="editing" :saving="saving" @save="handleSave" />
  </section>
</template>

<style scoped lang="scss">
.ops-page {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 18px;
  animation: ops-in 0.35s ease both;
}

@keyframes ops-in {
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

.ops-toolbar {
  display: grid;
  gap: 12px;
  padding: 14px 16px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
}

.ops-search {
  max-width: 420px;
}

.category-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.chip {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  padding: 6px 13px;
  border: 1px solid var(--border-soft);
  border-radius: 999px;
  background: var(--surface-muted);
  color: var(--text-regular);
  font-size: 13px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.chip:hover {
  border-color: color-mix(in srgb, var(--primary) 30%, var(--border-color));
  color: var(--primary);
}

.chip em {
  margin-left: 3px;
  color: var(--text-secondary);
  font-size: 12px;
  font-style: normal;
}

.chip.active {
  border-color: color-mix(in srgb, var(--primary) 40%, transparent);
  background: var(--primary-soft);
  color: var(--primary);
  font-weight: 600;
}

.chip.active em {
  color: inherit;
}

.ops-panel {
  padding: 15px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.command-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(330px, 100%), 1fr));
  gap: 12px;
}

.command-card {
  display: grid;
  gap: 10px;
  align-content: start;
  min-width: 0;
  padding: 14px;
  border: 1px solid var(--border-soft);
  border-radius: 12px;
  background: var(--surface-muted);
  transition: all 0.18s ease;
}

.command-card:hover {
  border-color: color-mix(in srgb, var(--primary) 25%, var(--border-color));
  background: color-mix(in srgb, var(--primary-soft) 30%, var(--surface));
}

.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  min-width: 0;
}

.card-head strong {
  min-width: 0;
  overflow: hidden;
  color: var(--text-primary);
  font-size: 14px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card-head :deep(.el-tag) {
  flex: none;
}

.command-box {
  position: relative;
}

.command-box code {
  display: block;
  min-width: 0;
  padding: 11px 76px 11px 12px;
  border: 1px solid var(--border-soft);
  border-radius: 10px;
  background: color-mix(in srgb, var(--primary) 5%, var(--surface));
  color: var(--text-primary);
  font-family: 'JetBrains Mono', 'Cascadia Code', Consolas, 'Courier New', monospace;
  font-size: 12.5px;
  line-height: 1.7;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.copy-btn {
  position: absolute;
  top: 6px;
  right: 6px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 9px;
  border: 1px solid var(--border-soft);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text-secondary);
  font-size: 12px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.copy-btn:hover {
  border-color: color-mix(in srgb, var(--primary) 35%, transparent);
  color: var(--primary);
}

.copy-btn.copied {
  border-color: color-mix(in srgb, var(--secondary) 40%, transparent);
  color: var(--secondary);
}

.command-desc {
  margin: 0;
  color: var(--text-secondary);
  font-size: 12.5px;
  line-height: 1.7;
}

.card-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.card-foot > span {
  color: var(--text-secondary);
  font-size: 12px;
}

.card-actions {
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

@media (max-width: 720px) {
  .ops-search {
    max-width: none;
  }
}
</style>

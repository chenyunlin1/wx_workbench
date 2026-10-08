<script setup lang="ts">
defineProps<{
  tags: string[]
  selected: string
}>()

const emit = defineEmits<{
  'update:selected': [tag: string]
}>()

const toggle = (tag: string) => {
  emit('update:selected', tag)
}
</script>

<template>
  <section class="tag-cloud" aria-label="技术标签云">
    <div class="tag-cloud__label">
      <span>技术标签</span>
      <small>点击筛选</small>
    </div>
    <div class="tag-cloud__track">
      <button
        v-for="tag in tags"
        :key="tag"
        class="tag-chip"
        :class="{ active: selected === tag }"
        type="button"
        @click="toggle(tag)"
      >
        {{ tag }}
      </button>
    </div>
  </section>
</template>

<style scoped lang="scss">
.tag-cloud {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 15px 18px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
}

.tag-cloud__label {
  min-width: 68px;
}

.tag-cloud__label span,
.tag-cloud__label small {
  display: block;
}

.tag-cloud__label span {
  color: var(--text-primary);
  font-size: 13px;
  font-weight: 700;
}

.tag-cloud__label small {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
}

.tag-cloud__track {
  display: flex;
  min-width: 0;
  flex: 1;
  gap: 8px;
  padding: 3px 2px;
  overflow-x: auto;
  scrollbar-width: thin;
}

.tag-chip {
  flex: none;
  padding: 6px 11px;
  border: 1px solid var(--border-soft);
  border-radius: 99px;
  color: var(--text-regular);
  background: var(--surface-muted);
  font-size: 13px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.tag-chip:hover {
  border-color: color-mix(in srgb, var(--primary) 35%, var(--border-color));
  color: var(--primary);
  background: var(--primary-soft);
}

.tag-chip.active {
  border-color: var(--primary);
  color: #fff;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
  box-shadow: 0 5px 14px color-mix(in srgb, var(--primary) 25%, transparent);
}

@media (max-width: 760px) {
  .tag-cloud {
    align-items: flex-start;
    flex-direction: column;
    gap: 9px;
  }

  .tag-cloud__track {
    width: 100%;
  }
}
</style>
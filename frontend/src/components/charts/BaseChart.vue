<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { echarts, type ChartOption } from '@/utils/echarts'

const props = withDefaults(
  defineProps<{
    option: ChartOption
    height?: number | string
    /** 无障碍描述，同时方便自动化测试确认图表内容 */
    ariaLabel?: string
  }>(),
  { height: 240, ariaLabel: '数据图表' },
)

const element = ref<HTMLElement | null>(null)
const instance = shallowRef<ReturnType<typeof echarts.init> | null>(null)

const chartHeight = () =>
  typeof props.height === 'number' ? `${props.height}px` : props.height

const render = () => {
  if (!instance.value) return
  // notMerge：主题切换或数据换批时整份覆盖，避免残留旧配置
  instance.value.setOption(props.option as never, { notMerge: true })
}

const resize = () => instance.value?.resize()

onMounted(() => {
  if (!element.value) return
  instance.value = echarts.init(element.value, undefined, { renderer: 'canvas' })
  render()
  window.addEventListener('resize', resize)
  // 容器宽度可能在布局稳定后才确定（例如卡片里首次渲染）
  requestAnimationFrame(resize)
})

watch(() => props.option, render, { deep: true })

onBeforeUnmount(() => {
  window.removeEventListener('resize', resize)
  instance.value?.dispose()
  instance.value = null
})

defineExpose({ resize })
</script>

<template>
  <div
    ref="element"
    class="base-chart"
    role="img"
    :aria-label="ariaLabel"
    :style="{ height: chartHeight() }"
  />
</template>

<style scoped>
.base-chart {
  width: 100%;
}
</style>

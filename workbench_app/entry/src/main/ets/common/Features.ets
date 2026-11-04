/** 功能入口：首页「全部功能」格子与「全部功能」页共用，新增功能只需在这里加一行 */
export class FeatureEntry {
  icon: string = ''
  label: string = ''
  target: string = ''

  constructor(icon: string, label: string, target: string) {
    this.icon = icon
    this.label = label
    this.target = target
  }
}

export const FEATURE_ENTRIES: FeatureEntry[] = [
  new FeatureEntry('📅', '日程管理', 'schedules'),
  new FeatureEntry('✅', '习惯健康', 'habits'),
  new FeatureEntry('🏋️', '减脂健身', 'workout'),
  new FeatureEntry('🏃', '跑步记录', 'runs'),
  new FeatureEntry('💰', '财务记账', 'finance'),
  new FeatureEntry('🎬', '书影音收藏', 'collection'),
  new FeatureEntry('🧠', '知识练习', 'practice'),
  new FeatureEntry('💼', '面试准备', 'interviews'),
  new FeatureEntry('🛒', '待买清单', 'shopping')
]

/** 首页默认展示的入口数量，其余收进「更多」；格子按 4 列排，最后一行不满是常态 */
export const HOME_FEATURE_LIMIT: number = 12

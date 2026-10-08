import { promptAction } from '@kit.ArkUI'

/** 轻提示 */
export function toast(message: string): void {
  promptAction.showToast({ message: message, duration: 2000 })
}

/** 通用确认弹窗 */
export function confirm(message: string, onOk: () => void): void {
  AlertDialog.show({
    message: message,
    gridCount: 4,
    primaryButton: {
      value: '取消',
      action: () => {
      }
    },
    secondaryButton: {
      value: '确定',
      fontColor: '#FFFFFF',
      backgroundColor: '#F87171',
      action: () => {
        onOk()
      }
    }
  })
}

/** 日期与文本格式化工具 */
export class Fmt {
  static pad2(n: number): string {
    return n < 10 ? '0' + n.toString() : n.toString()
  }

  /** Date -> YYYY-MM-DD */
  static date(d: Date): string {
    return `${d.getFullYear()}-${Fmt.pad2(d.getMonth() + 1)}-${Fmt.pad2(d.getDate())}`
  }

  /** Date -> YYYY-MM-DD HH:mm:ss */
  static dateTime(d: Date): string {
    return `${Fmt.date(d)} ${Fmt.pad2(d.getHours())}:${Fmt.pad2(d.getMinutes())}:00`
  }

  /** YYYY-MM */
  static month(d: Date): string {
    return `${d.getFullYear()}-${Fmt.pad2(d.getMonth() + 1)}`
  }

  static today(): string {
    return Fmt.date(new Date())
  }

  static now(): string {
    return Fmt.dateTime(new Date())
  }

  static addDays(base: string, days: number): string {
    const parts = base.split('-')
    const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
    d.setDate(d.getDate() + days)
    return Fmt.date(d)
  }

  static addMonths(base: string, months: number): string {
    const y = parseInt(base.substring(0, 4))
    const m = parseInt(base.substring(5, 7)) - 1 + months
    const d = new Date(y, m, 1)
    return Fmt.month(d)
  }

  /** 'YYYY-MM-DD HH:mm:ss' -> Date */
  static parse(value: string): Date {
    return new Date(value.replace(' ', 'T'))
  }

  static weekday(dateStr: string): string {
    const names: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    const parts = dateStr.split('-')
    const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
    return names[d.getDay()]
  }

  /** 去掉时间部分 */
  static dateOnly(value: string): string {
    return value.length >= 10 ? value.substring(0, 10) : value
  }

  /** 取 HH:mm */
  static timeOnly(value: string): string {
    return value.length >= 16 ? value.substring(11, 16) : value
  }

  /** MM-DD 展示 */
  static shortDate(value: string): string {
    const s = Fmt.dateOnly(value)
    return s.length === 10 ? s.substring(5, 10) : s
  }

  /** 金额，保留两位 */
  static money(n: number): string {
    return n.toFixed(2)
  }

  /** 金额简写：1.2w / 8600 */
  static moneyShort(n: number): string {
    const abs = Math.abs(n)
    if (abs >= 10000) {
      return (n / 10000).toFixed(1) + 'w'
    }
    return Math.round(n).toString()
  }

  /** 相对天数：今天/明天/MM-DD */
  static relativeDay(dateStr: string): string {
    const day = Fmt.dateOnly(dateStr)
    if (day === Fmt.today()) {
      return '今天'
    }
    if (day === Fmt.addDays(Fmt.today(), 1)) {
      return '明天'
    }
    return day.substring(5, 10)
  }

  /** 简单的 HTML 转义与换行处理，用于 AI / 知识内容展示 */
  static plainContent(content: string): string {
    return content
      .replace(/<br\s*\/?>/g, '\n')
      .replace(/<[^>]+>/g, '')
  }

  /** 把标签数组拼成文本 */
  static joinTags(tags: string[]): string {
    return tags.join(' · ')
  }
}

/** 常用选项集合（与网页端保持一致） */
export class Options {
  static readonly SCHEDULE_CATEGORIES: string[] = ['日程', '会议', '学习', '面试', '提醒', '其他']
  static readonly PRIORITIES: string[] = ['high', 'medium', 'low']
  static readonly LEARNING_STATUS: string[] = ['todo', 'doing', 'done']
  static readonly INTERVIEW_STATUS: string[] = ['pending', 'passed', 'rejected', 'cancelled']
  static readonly WORKOUT_TYPES: string[] =
    ['running', 'strength', 'cycling', 'swimming', 'yoga', 'hiit', 'walking', 'other']
  static readonly WORKOUT_INTENSITY: string[] = ['low', 'medium', 'high']
  static readonly COLLECTION_TYPES: string[] = ['book', 'movie', 'music']
  static readonly AI_MODELS: string[] = ['deepseek-chat', 'deepseek-reasoner']

  static readonly WORKOUT_TYPE_META: Record<string, string> = {
    'running': '🏃 跑步',
    'strength': '🏋️ 力量',
    'cycling': '🚴 骑行',
    'swimming': '🏊 游泳',
    'yoga': '🧘 瑜伽',
    'hiit': '⚡ HIIT',
    'walking': '🚶 快走',
    'other': '🤸 其他'
  }

  static readonly INTENSITY_META: Record<string, string> = {
    'low': '低强度',
    'medium': '中等强度',
    'high': '高强度'
  }

  static readonly INTERVIEW_STATUS_META: Record<string, string> = {
    'pending': '待进行',
    'passed': '通过',
    'rejected': '未通过',
    'cancelled': '已取消'
  }

  static readonly LEARNING_STATUS_META: Record<string, string> = {
    'todo': '待开始',
    'doing': '进行中',
    'done': '已完成'
  }

  static workoutTypeLabel(type: string): string {
    const label = Options.WORKOUT_TYPE_META[type]
    return label === undefined ? type : label
  }

  static workoutTypeName(type: string): string {
    if (type === 'running') {
      return '跑步'
    }
    if (type === 'strength') {
      return '力量'
    }
    if (type === 'cycling') {
      return '骑行'
    }
    if (type === 'swimming') {
      return '游泳'
    }
    if (type === 'yoga') {
      return '瑜伽'
    }
    if (type === 'hiit') {
      return 'HIIT'
    }
    if (type === 'walking') {
      return '快走'
    }
    return '其他'
  }

  static workoutEmoji(type: string): string {
    if (type === 'running') {
      return '🏃'
    }
    if (type === 'strength') {
      return '🏋️'
    }
    if (type === 'cycling') {
      return '🚴'
    }
    if (type === 'swimming') {
      return '🏊'
    }
    if (type === 'yoga') {
      return '🧘'
    }
    if (type === 'hiit') {
      return '⚡'
    }
    if (type === 'walking') {
      return '🚶'
    }
    return '🤸'
  }

  static intensityLabel(intensity: string): string {
    const label = Options.INTENSITY_META[intensity]
    return label === undefined ? intensity : label
  }

  static interviewStatusLabel(status: string): string {
    const label = Options.INTERVIEW_STATUS_META[status]
    return label === undefined ? status : label
  }

  static learningStatusLabel(status: string): string {
    const label = Options.LEARNING_STATUS_META[status]
    return label === undefined ? status : label
  }

  /** 书影音：状态文案随类型变化 */
  static collectionStatusLabel(status: string, type: string): string {
    if (type === 'book') {
      return status === 'wish' ? '想读' : status === 'doing' ? '在读' : '读完'
    }
    if (type === 'movie') {
      return status === 'wish' ? '想看' : status === 'doing' ? '在看' : '看完'
    }
    return status === 'wish' ? '想听' : status === 'doing' ? '在听' : '听完'
  }

  static collectionTypeLabel(type: string): string {
    return type === 'book' ? '书籍' : type === 'movie' ? '影视' : '音乐'
  }
}

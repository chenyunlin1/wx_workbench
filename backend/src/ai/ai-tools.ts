/**
 * AI 工具调用目录。
 *
 * 这里的每个工具都对应一个既有的写接口：后端只负责把模型的 tool_calls 校验成一组「待执行动作」，
 * 真正发起创建请求的是客户端（网页端用 api/*.ts，鸿蒙端用 Api.ets），所以：
 * - properties 必须与各 CreateXxxDto 的字段完全一致，多一个键都会被全局 ValidationPipe 拒掉；
 * - 时间与金额在这里归一化，避免模型输出「明天下午三点」这类无法落库的值。
 */

export type AiActionStatus = 'pending' | 'done' | 'failed' | 'cancelled'

export interface AiActionField {
  label: string
  value: string
}

export interface AiAction {
  tool: string
  label: string
  args: Record<string, unknown>
  fields: AiActionField[]
  status: AiActionStatus
  error: string | null
}

/** 上游返回的原始 tool_call（流式时分片到达） */
export interface RawToolCall {
  id?: string
  function?: { name?: string; arguments?: string }
}

type ToolFieldType = 'string' | 'number' | 'integer' | 'boolean' | 'array'

interface ToolField {
  type: ToolFieldType
  description: string
  enum?: string[]
  enumLabels?: string[]
  maxLength?: number
  minimum?: number
  maximum?: number
  format?: 'date-time' | 'date'
}

export interface AiToolDef {
  name: string
  /** 卡片标题，如「新增日程」 */
  label: string
  description: string
  required: string[]
  properties: Record<string, ToolField>
  /** 字段中文名，供卡片展示 */
  titles: Record<string, string>
}

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

const twoDigits = (value: number) => String(value).padStart(2, '0')

/** 服务器所在时区的偏移，如 +08:00 —— 库里存的正是这个时区的墙上时间 */
const localOffset = (date: Date) => {
  const minutes = -date.getTimezoneOffset()
  const sign = minutes >= 0 ? '+' : '-'
  const abs = Math.abs(minutes)
  return `${sign}${twoDigits(Math.floor(abs / 60))}:${twoDigits(abs % 60)}`
}

/** 带时区偏移的本地时间：模型看到什么偏移，回填的工具参数就用什么偏移 */
const isoWithOffset = (date: Date) =>
  `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())}T${twoDigits(
    date.getHours(),
  )}:${twoDigits(date.getMinutes())}:${twoDigits(date.getSeconds())}${localOffset(date)}`

const DATE_TIME_HINT =
  'ISO-8601 时间，必须带时区偏移，且与系统提示中「当前时间」的偏移保持一致，如 2026-10-02T15:00:00+08:00'
const DATE_HINT = 'ISO-8601 日期，如 2026-10-02'

/**
 * 工具说明（不可被用户自定义提示词覆盖），随 system 消息一并下发。
 */
export const aiToolInstruction = (now: Date) =>
  [
    '# 写入操作',
    '你可以调用工具替用户在平台上创建记录，但工具只是「提交待确认的操作」，客户端才会真正写入数据库。',
    `1. 当前时间：${isoWithOffset(now)}（${WEEKDAYS[now.getDay()]}）。「明天 / 下周三」这类相对说法按此推算，日期推算不出把握时先反问。`,
    '2. 只在用户明确表达「记下 / 安排 / 加进 / 提醒我」这类意图时调用工具；只是询问、讨论或让你规划时，不要调用。',
    '3. 缺少必填信息（时间、金额等）时先追问，禁止编造数值；用户只给日期没给时间的，按各工具描述里的默认时间补全。',
    '4. 一句话里有多个待记事项时，分别调用多次工具，一个事项一次调用，不要合并也不要只挑其中一个。',
    '5. 已经存在于数据快照里的记录不要重复提交。',
    '6. 调用工具后附上的正文用简体中文写一句确认就好（如「两条记录已提交，点确认即可写入」），不要用英文，也不要重复卡片里已展示的字段。',
  ].join('\n')

export const AI_TOOLS: AiToolDef[] = [
  {
    name: 'create_schedule',
    label: '新增日程',
    description: '创建一个日程或提醒，必须有开始时间。用户说「安排…」「提醒我…」「明天三点…」时使用。',
    required: ['title', 'startTime'],
    titles: {
      title: '标题',
      startTime: '开始时间',
      endTime: '结束时间',
      category: '分类',
      priority: '优先级',
      isRemind: '开启提醒',
      remindBefore: '提前提醒（分钟）',
      description: '备注',
    },
    properties: {
      title: { type: 'string', description: '日程标题，不超过 160 字', maxLength: 160 },
      startTime: {
        type: 'string',
        description: `${DATE_TIME_HINT}；用户只说了哪天、没说几点时按当天 09:00 填写`,
        format: 'date-time',
      },
      endTime: {
        type: 'string',
        description: `${DATE_TIME_HINT}；用户没说结束时间就不要填`,
        format: 'date-time',
      },
      category: { type: 'string', description: '分类，如 会议 / 提醒 / 私人，不超过 40 字', maxLength: 40 },
      priority: {
        type: 'string',
        description: '优先级，默认 medium',
        enum: ['high', 'medium', 'low'],
        enumLabels: ['高', '中', '低'],
      },
      isRemind: { type: 'boolean', description: '是否开启提醒，用户明确要提醒时填 true' },
      remindBefore: {
        type: 'integer',
        description: '提前多少分钟提醒，仅 isRemind 为 true 时有效，默认 15',
        minimum: 0,
        maximum: 1440,
      },
      description: { type: 'string', description: '补充说明', maxLength: 500 },
    },
  },
  {
    name: 'create_finance_record',
    label: '记一笔账',
    description: '记一笔钱：花掉或收到的金额，含分类。凡是提到具体金额的消费或收入都用它，不要用训练记录。',
    required: ['type', 'amount', 'category', 'recordDate'],
    titles: { type: '收支', amount: '金额', category: '分类', remark: '备注', recordDate: '日期' },
    properties: {
      type: {
        type: 'string',
        description: 'income 表示收入，expense 表示支出',
        enum: ['income', 'expense'],
        enumLabels: ['收入', '支出'],
      },
      amount: { type: 'number', description: '金额（元），保留两位小数，必须大于 0', minimum: 0.01, maximum: 99999999 },
      category: { type: 'string', description: '分类，如 餐饮 / 交通 / 住房，不超过 80 字', maxLength: 80 },
      remark: { type: 'string', description: '备注，如「和朋友吃饭」', maxLength: 255 },
      recordDate: { type: 'string', description: DATE_TIME_HINT, format: 'date-time' },
    },
  },
  {
    name: 'check_in_habit',
    label: '习惯打卡',
    description: '给一个已有习惯打卡今天。habitName 必须与数据快照中的习惯名称完全一致。',
    required: ['habitName'],
    titles: { habitName: '习惯' },
    properties: {
      habitName: { type: 'string', description: '习惯名称，需与已有习惯同名', maxLength: 80 },
    },
  },
  {
    name: 'create_habit',
    label: '新建习惯',
    description: '新建一个想要养成的习惯条目，不是打卡。',
    required: ['name'],
    titles: { name: '名称', icon: '图标', streakDays: '起始连续天数' },
    properties: {
      name: { type: 'string', description: '习惯名称，如 早起', maxLength: 80 },
      icon: { type: 'string', description: '单个 emoji，如 🌅', maxLength: 32 },
      streakDays: { type: 'integer', description: '已有的连续天数，通常不填', minimum: 0, maximum: 100000 },
    },
  },
  {
    name: 'create_shopping_item',
    label: '加入待买清单',
    description: '把还想买、尚未购买的东西加入待买清单。已经花出去的钱用 create_finance_record。',
    required: ['name'],
    titles: { name: '名称', price: '预算（元）' },
    properties: {
      name: { type: 'string', description: '商品名称，如 机械键盘', maxLength: 160 },
      price: { type: 'number', description: '预算金额（元），不知道就不填', minimum: 0, maximum: 99999999 },
    },
  },
  {
    name: 'create_knowledge_note',
    label: '新增知识记录',
    description: '把用户想留存的知识、题目或答案写进知识库。type=note 是笔记，type=qa 是问答对。',
    required: ['type', 'title', 'content'],
    titles: { type: '类型', title: '标题', content: '内容', tags: '标签' },
    properties: {
      type: {
        type: 'string',
        description: 'note 笔记，qa 问答',
        enum: ['note', 'qa'],
        enumLabels: ['笔记', '问答'],
      },
      title: { type: 'string', description: '标题', maxLength: 255 },
      content: { type: 'string', description: '正文内容', maxLength: 8000 },
      tags: { type: 'array', description: '标签数组，最多 20 个，如 ["HarmonyOS", "面试"]' },
    },
  },
  {
    name: 'create_learning_task',
    label: '新增学习任务',
    description: '创建一条学习任务，可带预计时长。',
    required: ['title'],
    titles: { title: '任务', duration: '预计时长（分钟）', status: '状态' },
    properties: {
      title: { type: 'string', description: '任务名称，如 JVM 调优：GC 与内存模型', maxLength: 180 },
      duration: { type: 'integer', description: '预计投入分钟数', minimum: 0, maximum: 100000 },
      status: {
        type: 'string',
        description: 'todo 待办 / doing 进行中 / done 已完成，默认 todo',
        enum: ['todo', 'doing', 'done'],
        enumLabels: ['待办', '进行中', '已完成'],
      },
    },
  },
  {
    name: 'create_workout_record',
    label: '记录一次训练',
    description: '记录一次已完成的运动训练，重点是时长（分钟）。不是花钱，也不是日程安排。',
    required: ['type', 'duration', 'workoutDate'],
    titles: {
      type: '运动类型',
      title: '标题',
      duration: '时长（分钟）',
      distance: '距离（公里）',
      calories: '消耗（千卡）',
      intensity: '强度',
      workoutDate: '训练时间',
      note: '备注',
    },
    properties: {
      type: {
        type: 'string',
        description: '运动类型',
        enum: ['running', 'strength', 'cycling', 'swimming', 'yoga', 'hiit', 'walking', 'other'],
        enumLabels: ['跑步', '力量', '骑行', '游泳', '瑜伽', 'HIIT', '步行', '其他'],
      },
      title: { type: 'string', description: '本次训练标题，如 轻松跑 5 公里', maxLength: 120 },
      duration: { type: 'integer', description: '训练分钟数，1-1440', minimum: 1, maximum: 1440 },
      distance: { type: 'number', description: '距离（公里），最多两位小数', minimum: 0, maximum: 1000 },
      calories: { type: 'integer', description: '消耗千卡', minimum: 0, maximum: 20000 },
      intensity: {
        type: 'string',
        description: '训练强度，默认 medium',
        enum: ['low', 'medium', 'high'],
        enumLabels: ['低', '中', '高'],
      },
      workoutDate: { type: 'string', description: DATE_TIME_HINT, format: 'date-time' },
      note: { type: 'string', description: '备注', maxLength: 500 },
    },
  },
  {
    name: 'create_health_weight',
    label: '记录体重',
    description: '记录某一天的体重数字（公斤）。',
    required: ['weight', 'recordDate'],
    titles: { weight: '体重（公斤）', recordDate: '日期' },
    properties: {
      weight: { type: 'number', description: '体重（公斤），最多两位小数', minimum: 20, maximum: 300 },
      recordDate: { type: 'string', description: DATE_HINT, format: 'date' },
    },
  },
  {
    name: 'create_collection_item',
    label: '新增书影音',
    description: '把一本书、电影或音乐加入书影音收藏，可带状态与评分。',
    required: ['type', 'title'],
    titles: { type: '类型', title: '名称', status: '状态', rating: '评分', year: '年份', comment: '短评' },
    properties: {
      type: {
        type: 'string',
        description: '条目类型',
        enum: ['book', 'movie', 'music'],
        enumLabels: ['书', '电影', '音乐'],
      },
      title: { type: 'string', description: '书名 / 片名 / 曲名', maxLength: 180 },
      status: {
        type: 'string',
        description: 'wish 想读 / doing 在读 / done 已看完，默认 wish',
        enum: ['wish', 'doing', 'done'],
        enumLabels: ['想看', '在看', '已看完'],
      },
      rating: { type: 'integer', description: '评分 1-5，没看过就不要填', minimum: 1, maximum: 5 },
      year: { type: 'integer', description: '出版 / 上映年份', minimum: 0, maximum: 2100 },
      comment: { type: 'string', description: '短评', maxLength: 1000 },
    },
  },
  {
    name: 'create_interview',
    label: '新增面试',
    description: '记录一场面试的公司、岗位与时间。',
    required: ['company', 'position', 'interviewTime'],
    titles: { company: '公司', position: '岗位', interviewTime: '面试时间', status: '状态' },
    properties: {
      company: { type: 'string', description: '公司名称', maxLength: 120 },
      position: { type: 'string', description: '岗位名称', maxLength: 120 },
      interviewTime: { type: 'string', description: DATE_TIME_HINT, format: 'date-time' },
      status: {
        type: 'string',
        description: '默认 pending',
        enum: ['pending', 'passed', 'rejected', 'cancelled'],
        enumLabels: ['待处理', '已通过', '未通过', '已取消'],
      },
    },
  },
]

const toolMap = new Map<string, AiToolDef>(AI_TOOLS.map((tool) => [tool.name, tool]))

/**
 * 交给上游 chat/completions 的 tools 字段。
 * names 传入时只下发客户端能执行的工具，避免出现确认后无法落库的卡片。
 */
export const buildAiToolPayload = (names?: string[]) => {
  const allowed = names?.length ? new Set(names) : null
  return AI_TOOLS.filter((tool) => !allowed || allowed.has(tool.name)).map((tool) => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: {
        type: 'object',
        properties: Object.fromEntries(
          Object.entries(tool.properties).map(([key, field]) => {
            const schema: Record<string, unknown> = { type: field.type, description: field.description }
            if (field.enum) schema.enum = field.enum
            if (field.format) schema.format = field.format
            if (field.maxLength) schema.maxLength = field.maxLength
            if (field.minimum !== undefined) schema.minimum = field.minimum
            if (field.maximum !== undefined) schema.maximum = field.maximum
            if (field.type === 'array') schema.items = { type: 'string' }
            return [key, schema]
          }),
        ),
        required: tool.required,
        additionalProperties: false,
      },
    },
  }))
}

/**
 * 模型可能给出 `2026-10-02 15:00`、`2026-10-02T15:00`、`2026-10-02` 等各种写法，
 * 而 DTO 要求 @IsDateString。无时区偏移时按服务器时区补全，不依赖运行环境的隐式解析。
 */
const normalizeDateTime = (raw: string, dateOnly: boolean): string | null => {
  const text = raw.trim()
  if (dateOnly) {
    const date = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
    if (date) return `${date[1]}-${date[2]}-${date[3]}`
    const iso = /^(\d{4})-(\d{2})-(\d{2})[T ]/.exec(text)
    return iso ? `${iso[1]}-${iso[2]}-${iso[3]}` : null
  }

  const offset = localOffset(new Date())
  const matched = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/.exec(
    text,
  )
  if (!matched) {
    const parsed = new Date(text)
    if (Number.isNaN(parsed.getTime())) return null
    return `${parsed.getFullYear()}-${twoDigits(parsed.getMonth() + 1)}-${twoDigits(parsed.getDate())}T${twoDigits(
      parsed.getHours(),
    )}:${twoDigits(parsed.getMinutes())}:00${offset}`
  }

  const [, year, month, day, hour, minute, second, , tz] = matched
  const date = `${year}-${month}-${day}`
  if (tz) return `${date}T${hour ?? '00'}:${minute ?? '00'}:${second ?? '00'}${tz === 'Z' ? '+00:00' : tz}`
  return `${date}T${hour ?? '09'}:${minute ?? '00'}:${second ?? '00'}${offset}`
}

const displayOf = (value: unknown, field: ToolField): string => {
  if (typeof value === 'boolean') return value ? '是' : '否'
  if (Array.isArray(value)) return value.join('、')
  const text = String(value)
  if (field.enum && field.enumLabels) {
    const index = field.enum.indexOf(text)
    if (index >= 0) return field.enumLabels[index]
  }
  // args 里保留完整 ISO 时间，卡片上只显示到分钟
  if (field.format === 'date-time' && text.length >= 16) return `${text.slice(0, 10)} ${text.slice(11, 16)}`
  return text
}

const coerceValue = (raw: unknown, field: ToolField): unknown => {
  if (raw === undefined || raw === null) return undefined

  switch (field.type) {
    case 'boolean':
      if (typeof raw === 'boolean') return raw
      if (typeof raw === 'string') {
        const text = raw.trim().toLowerCase()
        if (['true', '1', 'yes', '是'].includes(text)) return true
        if (['false', '0', 'no', '否'].includes(text)) return false
      }
      return undefined

    case 'number':
    case 'integer': {
      const num = typeof raw === 'number' ? raw : Number(String(raw).replace(/[^\d.-]/g, ''))
      if (!Number.isFinite(num)) return undefined
      const value = field.type === 'integer' ? Math.trunc(num) : Math.round(num * 100) / 100
      if (field.minimum !== undefined && value < field.minimum) return undefined
      if (field.maximum !== undefined && value > field.maximum) return undefined
      return value
    }

    case 'array': {
      const list = Array.isArray(raw)
        ? raw
        : typeof raw === 'string'
          ? raw.split(/[,，、]/)
          : []
      const tags = [...new Set(list.map((item) => String(item).trim()).filter((item) => item.length > 0))].slice(0, 20)
      return tags.length ? tags : undefined
    }

    default: {
      let text = typeof raw === 'string' ? raw : String(raw)
      if (field.format) {
        const normalized = normalizeDateTime(text, field.format === 'date')
        return normalized ?? undefined
      }
      text = text.trim()
      if (!text) return undefined
      if (field.enum) {
        const lower = text.toLowerCase()
        const hit = field.enum.find((item) => item === lower || item.toLowerCase() === lower)
        return hit ?? undefined
      }
      if (field.maxLength && text.length > field.maxLength) text = text.slice(0, field.maxLength)
      return text
    }
  }
}

/** 把一个 tool_call 校验成待执行动作；不合法就丢弃，绝不让客户端拿着半截参数去撞 400 */
export const normalizeToolCall = (name?: string, argsJson?: string): AiAction | null => {
  if (!name) return null
  const tool = toolMap.get(name)
  if (!tool) return null

  let raw: unknown
  try {
    raw = JSON.parse(argsJson?.trim() || '{}')
  } catch {
    return null
  }
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const source = raw as Record<string, unknown>

  const args: Record<string, unknown> = {}
  const fields: AiActionField[] = []
  for (const [key, field] of Object.entries(tool.properties)) {
    const value = coerceValue(source[key], field)
    if (value === undefined) continue
    args[key] = value
    fields.push({ label: tool.titles[key] ?? key, value: displayOf(value, field) })
  }

  if (!tool.required.every((key) => args[key] !== undefined)) return null

  // 结束时间早于开始时间时丢掉，交给服务端的默认值，避免整条动作被 400 拒绝
  if (args.startTime && args.endTime && new Date(String(args.endTime)) < new Date(String(args.startTime))) {
    delete args.endTime
    const index = fields.findIndex((field) => field.label === tool.titles.endTime)
    if (index >= 0) fields.splice(index, 1)
  }
  // 未开启提醒时提前分钟数没有意义
  if (args.remindBefore && args.isRemind !== true) {
    delete args.remindBefore
    const index = fields.findIndex((field) => field.label === tool.titles.remindBefore)
    if (index >= 0) fields.splice(index, 1)
  }

  return { tool: tool.name, label: tool.label, args, fields, status: 'pending', error: null }
}

export const normalizeToolCalls = (calls: RawToolCall[]): AiAction[] => {
  const actions: AiAction[] = []
  for (const call of calls) {
    const action = normalizeToolCall(call.function?.name, call.function?.arguments)
    if (action) actions.push(action)
  }
  return actions
}

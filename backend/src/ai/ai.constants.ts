/** AI 助手可读取的平台数据范围。 */
export const AI_CONTEXT_SCOPES = [
  'schedules',
  'habits',
  'learning',
  'knowledge',
  'collections',
  'health',
  'workouts',
  'interviews',
  'finance',
  'shopping',
] as const

export type AiContextScope = (typeof AI_CONTEXT_SCOPES)[number]

export const AI_SCOPE_LABELS: Record<AiContextScope, string> = {
  schedules: '日程安排',
  habits: '习惯打卡',
  learning: '学习任务',
  knowledge: '学习知识库',
  collections: '书影音收藏',
  health: '健康体重',
  workouts: '健身训练',
  interviews: '面试安排',
  finance: '记账财务',
  shopping: '待买清单',
}

export const DEFAULT_AI_CONTEXT_SCOPES: AiContextScope[] = [...AI_CONTEXT_SCOPES]

export const DEFAULT_AI_PROVIDER = 'deepseek'
export const DEFAULT_AI_BASE_URL = 'https://api.deepseek.com'
export const DEFAULT_AI_MODEL = 'deepseek-chat'
export const DEFAULT_AI_TEMPERATURE = 0.7
export const AI_MODEL_OPTIONS = ['deepseek-chat', 'deepseek-reasoner'] as const

/** 系统提示词上限，避免把整个平台塞进 system 消息后超长。 */
export const AI_SYSTEM_PROMPT_MAX_LENGTH = 4000
export const AI_CONTEXT_MAX_LENGTH = 24000
export const AI_MESSAGE_MAX_LENGTH = 8000
export const AI_HISTORY_LIMIT = 20
export const AI_STREAM_MAX_TOKENS = 2048
export const AI_REQUEST_TIMEOUT_MS = 90_000
export const AI_STREAM_IDLE_TIMEOUT_MS = 60_000

export const DEFAULT_AI_SYSTEM_PROMPT = [
  '你是 LifeOS 个人生活工作台内置的 AI 助手，帮助用户理解并安排自己的生活、学习与工作。',
  '',
  '回答要求：',
  '1. 使用简体中文，语气自然、直接，必要时用 Markdown 列表或表格让结构更清晰。',
  '2. 系统消息中会附带该用户的真实数据快照（日程、习惯、学习任务、知识库、书影音收藏、面试、财务、健康、待买清单）。凡是涉及用户个人数据的问题，必须基于快照中的真实数据回答，并说明数据的时间范围。',
  '3. 快照中没有记录的信息，要明确说明“数据中没有相关记录”，禁止编造任何数字、日期或条目。',
  '4. 金额保留两位小数并带上单位“元”；统计类回答先给结论，再给依据。',
  '5. 需要建议时给出 3-5 条可立即执行的行动项，不要空泛说教。',
  '6. 回答保持精炼，除非用户要求展开，一般不超过 400 字。',
  '7. 用户提出「记一下 / 安排 / 打卡」这类诉求时，按后面的「写入操作」说明调用工具，把内容整理成待确认条目。',
].join('\n')

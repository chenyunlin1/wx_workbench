/**
 * 高驰（COROS）官方 MCP 服务的接入参数。
 *
 * 授权与接口地址都遵循 MCP 的 OAuth 2.1 规范：MCP 地址返回 401 时会用
 * WWW-Authenticate 头指向受保护资源元数据，再由它指向授权服务器，
 * 所以真实端点是「问出来的」而不是写死的，下面的常量只作兜底。
 */

export const COROS_MCP_URL = 'https://mcp.coros.com/mcp'
export const COROS_FALLBACK_AUTH_SERVER = 'https://mcpcn.coros.com'
export const COROS_CLIENT_NAME = 'LifeOS 个人生活工作台'
export const COROS_PROTOCOL_VERSION = '2025-03-26'

/** offline_access 才能拿到 refresh_token，否则每次过期都要重新扫码登录 */
export const COROS_SCOPES = ['openid', 'mcp.tools', 'offline_access'] as const

export const COROS_REQUEST_TIMEOUT_MS = 20_000
export const COROS_TOOL_TIMEOUT_MS = 45_000
export const COROS_STATE_TTL_MS = 10 * 60_000
export const COROS_DISCOVERY_TTL_MS = 6 * 60 * 60_000
/** 到期前一分钟内就当作过期，避免请求在路上失效 */
export const COROS_REFRESH_LEEWAY_MS = 60_000

/** 交给上游模型的工具名，用前缀区分「服务端执行的 MCP 工具」和「客户端执行的写库工具」 */
export const COROS_TOOL_PREFIX = 'coros__'
export const COROS_MAX_TOOL_NAME_LENGTH = 64

/** 高驰目前提供 34 个工具，留足余量，超出上限的工具会被静默丢掉 */
export const COROS_MAX_DISCOVERED_TOOLS = 64

/**
 * 全量工具的描述与 schema 约 107 KB（≈3.5 万 token），每轮对话都塞进去太贵。
 * 这里按优先级装到预算为止：读数据工具全给，写课表的三个大工具其次，
 * 训练库/FIT 文件下载这类本轮用不上的先略过。
 */
export const COROS_MODEL_TOOL_BUDGET_BYTES = 60_000

/** MCP 侧最多几轮「调用—回填—再问」，防止模型无限自我循环 */
export const COROS_MAX_TOOL_ROUNDS = 3
export const COROS_MAX_CALLS_PER_ROUND = 4
/** 工具结果会整段塞回上下文，跑步数据一多就是几千 token */
export const COROS_TOOL_RESULT_MAX_CHARS = 4_000

/** 同步窗口：一次最多拉多少天，以及逐日工具的分组大小 */
export const COROS_SYNC_DEFAULT_DAYS = 30
export const COROS_SYNC_MAX_DAYS = 180
export const COROS_HRV_CHUNK_DAYS = 7
/** 每次同步最多补取多少条活动的详细数据（每条一次调用，太慢） */
export const COROS_ACTIVITY_DETAIL_LIMIT = 12
/** 后台同步超过这个时间还挂着，就当作进程重启留下的僵尸状态 */
export const COROS_SYNC_STALE_MS = 5 * 60_000

/**
 * 挂给模型的工具顺序：先读数据，再写课表，其余按体积补位。
 * 高驰新增工具时不需要改这里，只是排在后面、可能被预算挤掉。
 */
export const COROS_MODEL_TOOL_PRIORITY = [
  'querySportRecords',
  'getActivityDetail',
  'queryActivityLapData',
  'analyzeActivityDetail',
  'queryDailyHealthData',
  'querySleepOverview',
  'querySleepHrv',
  'queryAvgHeartRate',
  'queryRestingHeartRate',
  'queryStressLevel',
  'queryStressTimeSeries',
  'queryHealthCheckTimeSeries',
  'queryFitnessAssessmentOverview',
  'queryTrainingLoadAssessment',
  'queryRecoveryStatus',
  'queryUserInfo',
  'queryDevices',
  'queryMenstruationCycles',
  'queryTrainingSchedule',
  'queryScheduledWorkoutDetails',
  'queryTrainingPlanLibrary',
  'queryTrainingPlanDetails',
  'queryWorkoutLibrary',
  'createScheduledWorkout',
  'updateScheduledWorkout',
  'createTrainingPlan',
]

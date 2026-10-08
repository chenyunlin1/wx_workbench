# LifeOS 个人生活工作台

一个前后端分离的全栈工作台项目，覆盖今日概览、日程、习惯、学习、面试、财务、健康和待买清单。UI 使用科技蓝与薄荷绿，支持深浅主题、响应式三列卡片布局和 JWT 登录。

## 目录结构

```text
.
├─ frontend/                  # Vue 3 + Vite + TypeScript
│  ├─ src/
│  │  ├─ api/                # Axios 实例与业务 API
│  │  ├─ components/
│  │  │  ├─ dashboard/       # 8 个独立 Dashboard 卡片
│  │  │  └─ layout/          # Sidebar / Header
│  │  ├─ layouts/            # 主布局
│  │  ├─ router/             # Vue Router
│  │  ├─ stores/             # Pinia 用户、主题、AI 会话状态
│  │  ├─ styles/theme.scss   # 明亮/暗黑 CSS 变量
│  │  ├─ types/              # 前端类型
│  │  ├─ utils/              # Markdown 渲染等工具
│  │  └─ views/              # 登录、Dashboard、财务、日程、知识库、练习、书影音收藏、习惯健康、减脂健身、待买清单、AI 助手、用户管理
│  ├─ .env.example
│  ├─ package.json
│  └─ vite.config.ts
├─ backend/                   # NestJS + TypeORM + MySQL
│  ├─ src/
│  │  ├─ auth/               # JWT 登录与用户信息
│  │  ├─ common/             # 响应拦截器、异常过滤器、Guard
│  │  ├─ dashboard/          # Dashboard 聚合接口
│  │  ├─ database/           # 演示数据初始化
│  │  ├─ entities/           # 领域实体
│  │  ├─ users/              # 用户 CRUD
│  │  ├─ schedules/          # 日程 CRUD
│  │  ├─ habits/             # 习惯 CRUD + 打卡
│  │  ├─ learning/           # 学习任务 CRUD
│  │  ├─ knowledge/          # 知识库 CRUD + CSV 导入导出
│  │  ├─ practice/           # 知识练习（闪卡 / 填空）
│  │  ├─ collection/         # 书影音收藏 CRUD + 年度统计
│  │  ├─ workout/            # 健身训练 CRUD + 训练统计
│  │  ├─ ai/                 # AI 助手：DeepSeek 对话、平台数据快照、密钥配置
│  │  ├─ interviews/         # 面试 CRUD
│  │  ├─ finance/            # 财务 CRUD + 月度统计
│  │  ├─ health/             # 健康 CRUD + 趋势统计
│  │  └─ shopping/           # 待买清单 CRUD
│  ├─ .env.example
│  ├─ nest-cli.json
│  └─ package.json
├─ scripts/                   # 本地 MySQL 启停、DeepSeek mock、Markdown 自检
├─ docker-compose.yml         # 本地 MySQL 8.4
├─ package.json               # npm workspaces + 一键启动
└─ README.md
```

## 技术栈

- 前端：Vue 3、TypeScript、Vite、Element Plus、Pinia、Vue Router、Axios、SCSS。
- 后端：NestJS、TypeORM、MySQL、JWT、Passport、Swagger、class-validator。
- AI：DeepSeek Chat Completions（OpenAI 兼容协议），SSE 流式输出，无额外 SDK 依赖。
- 工程：npm workspaces、并发启动、MySQL Docker Compose。

## 快速启动

环境要求：Node.js 20+、npm 10+、MySQL 8+。如果本机已安装 Docker，可直接使用根目录的 Compose 文件启动 MySQL。

```bash
# 1. 安装全部依赖
npm install

# 2. 启动 MySQL（已安装 Docker 时）
docker compose up -d

# 2'. 没有 Docker 时，用脚本启动本地 MySQL 8.4 实例
powershell -ExecutionPolicy Bypass -File .\scripts\start-mysql.ps1
# 首次运行会自动初始化数据目录、设置 root/root 并创建 life_workbench 库

# 3. 准备后端环境变量
Copy-Item backend/.env.example backend/.env

# 4. 同时启动前端和后端
npm run dev
```

启动后访问：

- 前端：<http://localhost:5174>
- 后端 API：<http://localhost:3000/api>
- Swagger：<http://localhost:3000/docs>

演示账号：`admin` / `admin123`。`SEED_DEMO_DATA=true` 时，首次启动会自动创建账号与近 7 日演示数据。

## 常用命令

```bash
npm run dev              # 同时启动前后端
npm run build            # 构建前后端
npm run lint             # 前后端类型检查
npm run seed -w backend  # 仅运行数据库初始化
```

## API 概览

统一成功响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

主要接口：

| 模块 | 接口 |
| --- | --- |
| Auth | `POST /api/auth/login`、`GET /api/auth/profile` |
| Dashboard | `GET /api/dashboard/summary` |
| Users | `GET/POST /api/users`、`GET/PATCH/DELETE /api/users/:id` |
| Schedules | `/api/schedules` CRUD（含 `/api/schedule` 单数别名） |
| Habits | `/api/habits` CRUD、`POST /api/habits/:id/check-in`、`DELETE /api/habits/:id/check-in`、`GET /api/habits/records`、`GET /api/habits/stats?days=14` |
| Learning | `/api/learning` CRUD |
| Knowledge | `/api/knowledge` CRUD、`GET /api/knowledge/tags`、`GET /api/knowledge/export`、`POST /api/knowledge/import` |
| Practice | `GET /api/practice/count`、`GET /api/practice/generate`、`GET /api/practice/tags`、`POST /api/practice/result` |
| Collection | `/api/collection` CRUD、`GET /api/collection/stats?year=YYYY`、`GET /api/collection/years` |
| AI | `GET/PUT /api/ai/settings`、`DELETE /api/ai/settings/key`、`POST /api/ai/settings/test`、`GET /api/ai/context`、`POST /api/ai/chat`、`POST /api/ai/chat/stream` |
| AI 会话 | `GET/POST /api/ai/conversations`、`GET/PATCH/DELETE /api/ai/conversations/:id` |
| Interviews | `/api/interviews` CRUD |
| Finance | `/api/finance` CRUD、`GET /api/finance/summary`、`GET /api/finance/stats`、`GET /api/finance/categories` |
| Health | `GET /api/health/records`（记录列表）、`/api/health/:id` 与 `POST/PATCH/DELETE /api/health` CRUD、`GET /api/health/trend?limit=7` |
| Workout | `/api/workout` CRUD、`GET /api/workout/stats?days=7` |
| Shopping | `/api/shopping` CRUD |

除登录与健康检查外，请求需要携带：

```http
Authorization: Bearer <accessToken>
```

> `GET /api/health` 是应用健康检查（返回服务状态），体重记录列表在 `GET /api/health/records`。

## 习惯健康

入口：左侧菜单「习惯健康」（`/habits`），把习惯打卡与体重记录放在一页。

- **概览**：今日打卡（x/y 与完成率）、本周完成率（近 7 天打卡次数 / 可打卡次数）、最长连续天数、近 14 天打卡总数。
- **今日打卡**：每个习惯一张卡片，显示图标、连续天数、本周完成情况与最近 7 天圆点，右侧按钮一键打卡/取消打卡（取消会回退连续天数）；卡片上可直接编辑或删除习惯。
- **打卡热力条**：近 14 天每天一格，颜色深浅表示当天打卡数量。
- **健康体重**：最近 30 次体重折线图、最新体重与较上次的变化、区间范围；下方是体重记录列表，支持新增/编辑/删除。
- 表 `habits` / `habit_records` / `health_records`；`SEED_DEMO_DATA=true` 时首次启动会补最近两周的打卡历史（留有空缺）。

## 减脂健身

入口：左侧菜单「减脂健身」（`/fitness`），记录训练并观察体重变化。

- **概览**：窗口内（近 7 / 14 / 30 天可切换）训练次数、总时长、总消耗、连续训练天数，并附本月与累计数据。
- **训练分布**：每日训练时长柱状图 + 按类型（跑步/力量/骑行/游泳/瑜伽/HIIT/快走/其他）汇总的次数、时长、消耗与占比条。
- **体重趋势**：复用体重记录，展示最近 30 次曲线与区间变化。
- **训练记录**：分页列表，显示训练名称、时长、消耗、距离、强度标签与备注，支持按类型筛选、新增、编辑、删除。
- 训练字段：类型、名称（可选）、时长、消耗（可选）、距离（可选，仅跑步/骑行/游泳/快走显示）、强度、训练时间、备注；表 `workouts`。

## 待买清单

入口：左侧菜单「待买清单」（`/shopping`）。

- **概览**：待买件数（附平均单价）、待买合计、已买合计。
- **快速添加**：顶部一行输入名称（可带价格）后回车即入库，不必打开弹窗。
- **筛选与排序**：全部 / 待买 / 已买切换、关键词搜索、按最近添加或价格排序。
- **清单操作**：勾选即标记为已买（再点一次恢复待买），支持编辑、删除，以及一键「清理已买」。
- 表 `shopping_items`。

## 书影音收藏

入口：左侧菜单「书影音收藏」（`/collection`），用来记录书籍、影视、音乐三类收藏。

- **年度统计**：可切换年份，展示该年新增收藏数、已完成数，以及书籍/影视/音乐分布；下方一行补充累计条数、想读想看想听、进行中与平均评分。
- **两种浏览方式**：封面墙（`3:4` 海报卡，悬停出现编辑/删除，点击状态标签可按 想读 → 在读 → 读完 循环切换）与列表（一屏看到标题、类型、状态、评分、年份、短评，状态可直接下拉修改）。视图选择会记在浏览器本地。
- **筛选与排序**：类型标签页、状态、关键词（标题或短评模糊匹配）、排序（最近添加 / 评分最高 / 年份最新 / 标题）。
- **字段**：标题、类型、状态、评分（1-5）、年份、封面链接、短评。封面链接留空时用类型渐变色 + 标题首字生成占位封面，外链加载失败也会自动回退。
- **状态文案随类型变化**：书籍是「想读/在读/读完」，影视是「想看/在看/看完」，音乐是「想听/在听/听完」。
- 数据表 `collections` 由 TypeORM `synchronize` 自动创建；`SEED_DEMO_DATA=true` 时首次启动会写入 7 条演示收藏。

## AI 助手

入口：左侧菜单「AI 助手」或右上角「问问 AI」。助手基于 DeepSeek，可以读取当前用户在整个平台的数据。

### 配置密钥

两种方式任选其一：

1. 页面内配置（推荐）：`AI 助手 → 设置 → 模型配置`，填写 API Key 后保存。密钥按用户保存在 `ai_settings` 表，接口只返回脱敏预览（如 `sk-ab****cdef`），页面可随时「清除已保存的密钥」。
2. 后端环境变量：在 `backend/.env` 中设置 `DEEPSEEK_API_KEY`（可选 `DEEPSEEK_BASE_URL`、`DEEPSEEK_MODEL`）。

> 密钥目前在数据库中以明文存放，仅适合本地自用；生产环境建议改用 `DEEPSEEK_API_KEY` 环境变量或独立的密钥管理服务。

同一张表单还能调整接口地址、模型（`deepseek-chat` / `deepseek-reasoner`）、temperature 与系统提示词，并可直接「测试连接」验证密钥与模型是否可用。

### 平台数据上下文

每次提问前，后端会把当前用户的数据汇总成一份 Markdown 快照，作为 system 消息的一部分发送给模型，涵盖 10 类数据：

| 范围 key | 内容 |
| --- | --- |
| `schedules` | 今日与未来 7 天日程、优先级、完成状态 |
| `habits` | 习惯、连续天数、今日是否打卡 |
| `learning` | 学习任务状态与时长统计 |
| `knowledge` | 知识库条目（标题、标签、内容摘要） |
| `collections` | 书影音收藏（类型、状态、评分、年份、短评） |
| `health` | 最近 10 次体重与均值 |
| `workouts` | 训练记录与近 7 天训练量、类型 |
| `interviews` | 待进行的面试 |
| `finance` | 本月/上月收支、支出分类、最近明细 |
| `shopping` | 未购买条目与合计金额 |

- 范围可在「设置 → 数据上下文」中勾选，也可在请求里用 `contextScope` 覆盖；快照上限 24000 字，超出会截断并在文末标注。
- 「数据上下文」页签内提供快照预览，可以看到实际发送给模型的原文。
- 内置系统提示词要求模型只依据快照作答、数据缺失时明确说明；快照为空的范围会被显式告知，避免编造数字。

### 会话列表

- 左侧一栏管理会话：**新建对话 / 切换 / 重命名 / 删除**；每条显示标题、最后一条消息摘要、活跃时间与消息条数。
- 会话与消息都落在数据库（`ai_conversations` / `ai_messages`），刷新页面、换浏览器甚至换设备都能接着聊；表间级联删除。
- 标题无需手动起：第一条消息发出后按内容自动命名（最长 24 字），手动改过就不会再被覆盖。
- 点「新建对话」先进入草稿态，发出第一条消息时才真正建会话，避免残留一堆空会话；切换会话时聊天记录从接口加载。
- 窄屏（≤900px）会话栏收进抽屉，由右上角「会话」按钮打开。

### 流式对话

- 前端用 `fetch` 读取 `POST /api/ai/chat/stream` 的 SSE 帧：`meta`（模型、本次上下文概览与会话 ID）、`reasoning`（推理模型的思考过程）、`delta`（增量正文）、`done`（用量与耗时）、`error`（可读错误）。
- 请求带上 `conversationId` 即续写该会话，历史以数据库为准；不带而只给 `content` 则自动新建会话；只给 `messages` 时为无状态调用、不落库。
- 助手回复先落库再发 `done`，因此前端收到结束信号后立刻刷新的列表就是最新的。
- 流式不可用时自动回退到 `POST /api/ai/chat` 一次性返回；生成过程中可随时「停止生成」，客户端断开时后端会中断对上游的请求。
- 未配置密钥、密钥无效（401）、余额不足（402）、地址或模型错误（404）、限流（429）等都会转换成中文提示，不会把上游原始报文直接抛给用户。

### 没有真实密钥时的联调

仓库自带一个假的 DeepSeek 接口，可完整验证密钥校验、SSE 与上下文注入：

```bash
node scripts/mock-deepseek.mjs        # 监听 http://127.0.0.1:8788
```

把「接口地址」改成 `http://127.0.0.1:8788` 即可对话：任意非空密钥都通过，密钥中包含 `invalid` 时返回 401。

前端自实现的 Markdown 渲染器（无第三方依赖）与其余几个自检脚本：

```bash
node scripts/check-markdown.mjs      # Markdown 渲染与 XSS 转义
node scripts/check-sse.mjs           # SSE 拼帧（可传真实抓包文件作为参数）
node scripts/check-reactivity.mjs    # Pinia 响应式写法（流式回显依赖它）
node scripts/check-ai-ui.mjs         # headless Chrome 跑一轮真实对话，验证流式回显（需已配置密钥）
node scripts/check-collection-ui.mjs # headless Chrome 验证书影音收藏页面与新增流程
node scripts/check-life-ui.mjs       # headless Chrome 验证习惯健康 / 减脂健身 / 待买清单三个页面
```

## 主题与响应式

- `theme.scss` 同时定义 `:root` 与 `html.dark` 下的背景、卡片、边框、文字和状态色。
- Element Plus 暗色变量通过 `element-plus/theme-chalk/dark/css-vars.css` 接入。
- 页面加载前会在 `index.html` 中读取主题，避免暗色模式闪烁。
- Dashboard 大屏 3 列、中屏 2 列、小屏 1 列；900px 以下侧边栏切换为抽屉。

## 数据库说明

开发环境默认启用 `synchronize`，便于首次直接运行。生产环境请关闭自动同步，并使用 TypeORM migration 管理表结构：

```env
NODE_ENV=production
DB_LOGGING=false
```

同时务必替换 `JWT_SECRET`，并通过 `CORS_ORIGINS` 限制允许访问的前端域名。
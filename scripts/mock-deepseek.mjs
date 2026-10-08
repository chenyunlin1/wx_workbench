/**
 * 本地假的 DeepSeek 接口，用于在没有真实密钥时验证 AI 助手的完整链路：
 * 密钥校验、流式 SSE、非流式补全、上下文快照是否真的随请求发出。
 *
 *   node scripts/mock-deepseek.mjs
 *   然后在「AI 助手 → 设置」里把接口地址填成 http://127.0.0.1:8788
 *
 * 任意非空 API Key 都会通过；密钥里包含 "invalid" 时返回 401，用于验证错误提示。
 */
import { createServer } from 'node:http'

const port = Number(process.env.MOCK_PORT || 8788)

const readBody = (request) =>
  new Promise((resolve) => {
    let data = ''
    request.setEncoding('utf-8')
    request.on('data', (chunk) => {
      data += chunk
    })
    request.on('end', () => resolve(data))
  })

const buildReply = (payload) => {
  const messages = Array.isArray(payload.messages) ? payload.messages : []
  const system = messages.find((message) => message.role === 'system')?.content ?? ''
  const user = [...messages].reverse().find((message) => message.role === 'user')?.content ?? ''
  const sections = [...system.matchAll(/^## (.+?)(?:（|$)/gm)].map((match) => match[1])

  return [
    `（mock 回复）收到 ${messages.length} 条消息，system 快照 ${system.length} 字。`,
    `检测到的数据段（${sections.length}）：${sections.length ? sections.join('、') : '（无）'}`,
    '',
    `你问的是：${user}`,
    '',
    '### 今日安排',
    '- 09:30-10:15 项目进度同步',
    '- 14:00-15:30 后端接口联调',
    '',
    '| 项目 | 数值 |',
    '| --- | --- |',
    '| 本月结余 | 14120.00 元 |',
    '',
    '```json',
    '{"mock": true}',
    '```',
  ].join('\n')
}

createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', 'http://localhost')
  if (!url.pathname.endsWith('/chat/completions')) {
    response.writeHead(404, { 'Content-Type': 'application/json' })
    response.end(JSON.stringify({ error: { message: 'mock: unknown path' } }))
    return
  }

  const authorization = request.headers.authorization ?? ''
  const raw = await readBody(request)

  let payload = {}
  try {
    payload = JSON.parse(raw)
  } catch {
    response.writeHead(400, { 'Content-Type': 'application/json' })
    response.end(JSON.stringify({ error: { message: 'mock: invalid json' } }))
    return
  }

  if (authorization.includes('invalid')) {
    response.writeHead(401, { 'Content-Type': 'application/json' })
    response.end(
      JSON.stringify({ error: { message: 'Authentication Fails, Your api key is invalid' } }),
    )
    return
  }

  const model = payload.model || 'deepseek-chat'
  const content = buildReply(payload)
  const usage = { prompt_tokens: 128, completion_tokens: 64, total_tokens: 192 }

  if (!payload.stream) {
    response.writeHead(200, { 'Content-Type': 'application/json' })
    response.end(
      JSON.stringify({
        id: 'mock-completion',
        model,
        choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
        usage,
      }),
    )
    return
  }

  response.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  })

  const send = (chunk) => response.write(`data: ${JSON.stringify(chunk)}\n\n`)
  const pieces = content.match(/[\s\S]{1,24}/g) ?? []
  let index = 0
  let reasoningSent = false

  const timer = setInterval(() => {
    if (model.includes('reasoner') && !reasoningSent) {
      reasoningSent = true
      send({
        id: 'mock',
        model,
        choices: [{ index: 0, delta: { reasoning_content: '先读取用户的平台数据快照，再组织回答。' } }],
      })
      return
    }

    if (index >= pieces.length) {
      clearInterval(timer)
      send({ id: 'mock', model, choices: [{ index: 0, delta: {}, finish_reason: 'stop' }], usage })
      response.write('data: [DONE]\n\n')
      response.end()
      return
    }

    send({ id: 'mock', model, choices: [{ index: 0, delta: { content: pieces[index] } }] })
    index += 1
  }, 35)

  response.on('close', () => clearInterval(timer))
}).listen(port, '127.0.0.1', () => {
  console.log(`mock deepseek listening on http://127.0.0.1:${port}`)
})

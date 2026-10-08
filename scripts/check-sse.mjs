/**
 * SSE 解析自检：模拟浏览器按任意字节切分读取响应体，
 * 验证 frontend/src/utils/sse.ts 能正确拼帧（包括中文被切在半个字符上的情况）。
 *
 *   node scripts/check-sse.mjs                    # 用内置样例
 *   node scripts/check-sse.mjs captured-stream.txt # 用真实抓到的流
 */
import { readFileSync } from 'node:fs'
import { parseSseChunk, parseSseFrame } from '../frontend/src/utils/sse.ts'

const SAMPLE = [
  'event: meta',
  'data: {"model":"deepseek-chat","context":{"scope":["schedules"]}}',
  '',
  'event: reasoning',
  'data: {"content":"先看用户的日程数据。"}',
  '',
  'event: delta',
  'data: {"content":"今天有 3 项安排："}',
  '',
  'event: delta',
  'data: {"content":"\\n- 09:30 项目进度同步"}',
  '',
  'event: delta',
  'data: {"content":"\\n- 14:00 后端接口联调"}',
  '',
  ': 心跳注释应被忽略',
  '',
  'event: done',
  'data: {"model":"deepseek-chat","finishReason":"stop","elapsedMs":1200}',
  '',
  '',
].join('\n')

const expectedFrom = (text) => {
  const parts = text.replace(/\r\n/g, '\n').split('\n\n')
  const events = []
  let content = ''
  let reasoning = ''
  for (const part of parts) {
    const frame = parseSseFrame(part)
    if (!frame) continue
    events.push(frame.event)
    const payload = JSON.parse(frame.data)
    if (frame.event === 'delta') content += payload.content ?? ''
    if (frame.event === 'reasoning') reasoning += payload.content ?? ''
  }
  return { events, content, reasoning }
}

/** 按固定字节大小切分，完全复刻 fetch reader + TextDecoder 的读取方式 */
const readWithChunkSize = (bytes, size) => {
  const decoder = new TextDecoder('utf-8')
  const events = []
  let content = ''
  let reasoning = ''
  let buffer = ''
  let offset = 0

  while (offset < bytes.length) {
    const slice = bytes.subarray(offset, Math.min(offset + size, bytes.length))
    offset += slice.length
    buffer += decoder.decode(slice, { stream: true })
    const parsed = parseSseChunk(buffer)
    buffer = parsed.rest
    for (const frame of parsed.frames) {
      events.push(frame.event)
      const payload = JSON.parse(frame.data)
      if (frame.event === 'delta') content += payload.content ?? ''
      if (frame.event === 'reasoning') reasoning += payload.content ?? ''
    }
  }

  const tail = parseSseFrame(buffer)
  if (tail) events.push(tail.event)

  return { events, content, reasoning }
}

const source = process.argv[2]
const text = source ? readFileSync(source, 'utf8') : SAMPLE
const bytes = Buffer.from(text, 'utf-8')

console.log(source ? `数据源：${source}（${bytes.length} 字节）` : '数据源：内置样例')
const expected = expectedFrom(text)
console.log(`参考解析：${expected.events.length} 帧，正文 ${expected.content.length} 字`)

let failures = 0
const check = (label, ok, detail) => {
  if (ok) {
    console.log(`ok    ${label}`)
  } else {
    failures += 1
    console.log(`FAIL  ${label}${detail ? ` → ${detail}` : ''}`)
  }
}

check('首个事件是 meta', expected.events[0] === 'meta', expected.events[0])
check('末个事件是 done', expected.events.at(-1) === 'done', expected.events.at(-1))
check('正文非空', expected.content.length > 0)

for (const size of [1, 2, 3, 7, 64, 4096, bytes.length]) {
  const actual = readWithChunkSize(bytes, size)
  const label = `按 ${size} 字节分片读取`
  check(
    `${label}：事件序列一致`,
    actual.events.join('|') === expected.events.join('|'),
    `${actual.events.length} vs ${expected.events.length}`,
  )
  check(
    `${label}：正文完全一致`,
    actual.content === expected.content,
    `"${actual.content.slice(0, 40)}" vs "${expected.content.slice(0, 40)}"`,
  )
  check(`${label}：思考过程一致`, actual.reasoning === expected.reasoning)
}

// 边界情况
const crlf = parseSseChunk('event: delta\r\ndata: {"content":"a"}\r\n\r\n')
check('兼容 CRLF 分隔', crlf.frames.length === 1 && crlf.frames[0].event === 'delta')

const partial = parseSseChunk('event: delta\ndata: {"content":"半')
check('半截数据不产生帧并留在 rest', partial.frames.length === 0 && partial.rest.includes('半'))

const multiline = parseSseFrame('event: delta\ndata: {"content":"x"}\ndata: {"content":"y"}')
check('多行 data 合并', multiline?.data === '{"content":"x"}\n{"content":"y"}')

check('空帧返回 null', parseSseFrame('\n\n') === null)

console.log(failures === 0 ? '\n全部通过' : `\n${failures} 项失败`)
process.exit(failures === 0 ? 0 : 1)

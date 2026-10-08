/**
 * AI 助手浏览器端验证：会话列表 + 流式回显 + 落库持久化。
 *
 *   node scripts/check-ai-ui.mjs ["要问的问题"]
 *
 * 需要后端(3000)、前端 dev(5174) 与已配置的 API Key，会真实消耗一次极小的模型调用。
 * 测试创建的会话会在结束时清理。
 */
import { apiClient, createChecker, openBrowser, signIn, sleep } from './lib/browser.mjs'

const API = 'http://localhost:3000/api'
const ORIGIN = 'http://localhost:5174'
const PORT = 9333
const QUESTION = process.argv[2] ?? '请用大约 100 字介绍 Vue3 的响应式原理'
const POLL_INTERVAL_MS = 80
const POLL_ATTEMPTS = 300

const { check, failures } = createChecker()
let browser = null
let api = null
let createdId = null

const readHeaderTags = async () => {
  let tags = []
  for (let attempt = 0; attempt < 40; attempt += 1) {
    tags = await browser.evaluate(
      `[...document.querySelectorAll('.head-actions .el-tag')].map((el) => el.innerText.trim())`,
    )
    if (tags.some((tag) => tag.includes('密钥'))) break
    await sleep(200)
  }
  return tags
}

try {
  browser = await openBrowser({ port: PORT })
  const token = await signIn(browser, {
    apiUrl: API,
    appOrigin: ORIGIN,
    username: 'admin',
    password: 'admin123',
  })
  api = apiClient(API, token)

  const before = (await api.request('/ai/conversations')).data
  console.log(`      已有会话：${before.length} 个`)

  // 会话侧栏在窄屏会收进抽屉，这里用桌面视口验证
  await browser.send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  })

  await browser.navigate(`${ORIGIN}/ai`)
  const ready = await browser.waitFor(`Boolean(document.querySelector('.composer textarea'))`)
  check('AI 页面渲染出输入框', ready === true)
  check('会话列表面板已渲染', await browser.waitFor(`Boolean(document.querySelector('.conversation-pane .new-button'))`))

  const listCount = await browser.evaluate(`document.querySelectorAll('.conversation-item').length`)
  console.log(`      列表中的会话条目：${listCount}`)

  const headerTags = await readHeaderTags()
  console.log(`      头部标签：${JSON.stringify(headerTags)}`)
  const hasContextTag = headerTags.some((tag) => /\/\d+ 类/.test(tag))
  const hasEmptyTag = headerTags.includes('未携带平台数据')
  check('头部只显示一种上下文状态', hasContextTag !== hasEmptyTag, JSON.stringify(headerTags))

  /* ---------------- 新建对话 ---------------- */
  await browser.evaluate(`document.querySelector('.conversation-pane .new-button').click(); 'create'`)
  await sleep(1200)
  const afterCreate = (await api.request('/ai/conversations')).data
  const created = afterCreate.find((item) => !before.some((old) => old.id === item.id))
  createdId = created?.id ?? null
  console.log(`      新建会话：${JSON.stringify(created ?? null)}`)
  check('新建对话已落库', Boolean(created))
  check('新会话默认标题为「新对话」', created?.title === '新对话', created?.title)
  check(
    '新会话在列表中被选中',
    await browser.evaluate(`
      (() => {
        const active = document.querySelector('.conversation-item.is-active')
        return Boolean(active && active.innerText.includes('新对话'))
      })()
    `),
  )

  /* ---------------- 发送消息（流式回显） ---------------- */
  await browser.evaluate(`document.querySelector('.composer textarea').focus(); 'focus'`)
  await browser.send('Input.insertText', { text: QUESTION })

  const inputState = await browser.evaluate(`
    (() => {
      const textarea = document.querySelector('.composer textarea')
      const button = [...document.querySelectorAll('.composer button')]
        .find((item) => item.innerText.includes('发送'))
      return { value: textarea.value, disabled: button ? button.disabled : null }
    })()
  `)
  check('输入框已填入问题', inputState.value === QUESTION, inputState.value)
  check('发送按钮可用', inputState.disabled === false, String(inputState.disabled))

  await browser.evaluate(`
    [...document.querySelectorAll('.composer button')]
      .find((item) => item.innerText.includes('发送')).click()
    'clicked'
  `)
  await sleep(200)
  check(
    '点击后立即出现气泡',
    (await browser.evaluate(`document.querySelectorAll('.bubble').length`)) > 0,
  )

  const samples = []
  let lastText = ''
  let stuckThinking = false
  let finalText = ''

  for (let attempt = 0; attempt < POLL_ATTEMPTS; attempt += 1) {
    await sleep(POLL_INTERVAL_MS)
    const state = await browser.evaluate(`
      (() => {
        const bubbles = [...document.querySelectorAll('.bubble')]
        const last = bubbles[bubbles.length - 1]
        return {
          text: last?.querySelector('.md-body')?.innerText ?? '',
          thinking: Boolean(last?.innerText?.includes('正在思考')),
          streaming: Boolean(last?.innerText?.includes('生成中')),
          chips: last?.querySelectorAll('.chip').length ?? 0,
          error: last?.querySelector('.error-note')?.innerText ?? '',
        }
      })()
    `)

    if (state.text && state.text !== lastText) {
      samples.push(state.text.length)
      lastText = state.text
    }
    if (!state.streaming && state.text) {
      finalText = state.text
      stuckThinking = state.thinking
      console.log(`      上下文标签 ${state.chips} 个｜错误信息：${state.error || '无'}`)
      break
    }
  }

  console.log(`      正文长度变化轨迹：${samples.join(' → ') || '（没有任何增长）'}`)
  console.log(`      最终正文：${finalText.replace(/\s+/g, ' ').slice(0, 100)}`)
  check('正文逐步增长（流式回显生效）', samples.length >= 2, `采样次数=${samples.length}`)
  check('最终正文非空', finalText.length > 0)
  check('没有卡在“正在思考”', finalText.length > 0 && !stuckThinking)
  check('没有渲染错误提示', !lastText.includes('模型没有返回内容'))

  /* ---------------- 落库与自动命名 ---------------- */
  await sleep(900)
  const detail = (await api.request(`/ai/conversations/${createdId}`)).data
  const messages = detail?.messages ?? []
  console.log(`      会话已存消息：${messages.length} 条｜标题：${detail?.conversation?.title}`)
  check('用户消息与助手回复都已落库', messages.length === 2, `messages=${messages.length}`)
  check('用户消息内容正确', messages[0]?.role === 'user' && messages[0]?.content === QUESTION)
  check('助手回复已落库且有内容', messages[1]?.role === 'assistant' && messages[1]?.content.length > 0)
  check('助手回复带上下文快照', Boolean(messages[1]?.contextMeta?.sections?.length))
  check(
    '会话标题按首条消息自动命名',
    Boolean(detail?.conversation?.title?.startsWith(QUESTION.slice(0, 6))),
    detail?.conversation?.title,
  )

  /* ---------------- 刷新后仍然存在 ---------------- */
  await browser.navigate(`${ORIGIN}/ai`)
  await browser.waitFor(`document.querySelectorAll('.conversation-item').length > 0`)
  await browser.waitFor(`document.querySelectorAll('.bubble').length > 0`)
  const restored = await browser.evaluate(`
    (() => {
      const items = [...document.querySelectorAll('.conversation-item')]
      const active = items.find((item) => item.classList.contains('is-active'))
      return {
        count: items.length,
        activeTitle: active?.querySelector('.item-title')?.innerText ?? '',
        bubbles: document.querySelectorAll('.bubble').length,
        chatTitle: document.querySelector('.chat-title strong')?.innerText ?? '',
      }
    })()
  `)
  console.log(`      刷新后：${JSON.stringify(restored)}`)
  check('刷新后会话仍在列表中', restored.count >= 1, String(restored.count))
  check('刷新后自动打开最近会话并恢复消息', restored.bubbles >= 2, String(restored.bubbles))

  /* ---------------- 重命名 ---------------- */
  const newTitle = `重命名验证 ${Date.now().toString().slice(-5)}`
  await browser.evaluate(`
    (() => {
      const active = document.querySelector('.conversation-item.is-active')
      active.querySelectorAll('.item-actions button')[0].click()
      return 'rename'
    })()
  `)
  await browser.waitFor(`Boolean(document.querySelector('.conversation-item.is-active input'))`)
  await browser.evaluate(`document.querySelector('.conversation-item.is-active input').focus(); 'focus'`)
  await browser.evaluate(`
    (() => {
      const input = document.querySelector('.conversation-item.is-active input')
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set
      setter.call(input, '')
      input.dispatchEvent(new Event('input', { bubbles: true }))
      return 'clear'
    })()
  `)
  await browser.send('Input.insertText', { text: newTitle })
  await browser.send('Input.dispatchKeyEvent', {
    type: 'keyDown',
    key: 'Enter',
    code: 'Enter',
    windowsVirtualKeyCode: 13,
    nativeVirtualKeyCode: 13,
  })
  await browser.send('Input.dispatchKeyEvent', {
    type: 'keyUp',
    key: 'Enter',
    code: 'Enter',
    windowsVirtualKeyCode: 13,
    nativeVirtualKeyCode: 13,
  })
  await sleep(1200)
  const renamed = (await api.request('/ai/conversations')).data.find((item) => item.id === createdId)
  console.log(`      重命名后标题：${renamed?.title}`)
  check('重命名已保存', renamed?.title === newTitle, renamed?.title)
  check(
    '列表与标题栏同步更新',
    await browser.evaluate(`
      (() => {
        const active = document.querySelector('.conversation-item.is-active .item-title')?.innerText ?? ''
        const head = document.querySelector('.chat-title strong')?.innerText ?? ''
        return active === ${JSON.stringify(newTitle)} && head === ${JSON.stringify(newTitle)}
      })()
    `),
  )

  /* ---------------- 删除 ---------------- */
  const countBeforeDelete = (await api.request('/ai/conversations')).data.length
  await browser.evaluate(`
    (() => {
      const active = document.querySelector('.conversation-item.is-active')
      active.querySelectorAll('.item-actions button')[1].click()
      return 'delete'
    })()
  `)
  check('删除确认框出现', await browser.waitFor(`Boolean(document.querySelector('.el-message-box'))`))
  await browser.evaluate(`
    (() => {
      const box = document.querySelector('.el-message-box')
      const confirm = [...box.querySelectorAll('button')].find((el) => el.innerText.includes('删除'))
      confirm.click()
      return 'confirm'
    })()
  `)
  await sleep(1400)
  const afterDelete = (await api.request('/ai/conversations')).data
  check('会话已从数据库删除', !afterDelete.some((item) => item.id === createdId))
  check('列表数量减少', afterDelete.length === countBeforeDelete - 1, `${afterDelete.length} vs ${countBeforeDelete}`)
  createdId = null

  check('页面无 JS 异常', browser.consoleErrors.length === 0, browser.consoleErrors.slice(0, 3).join(' | '))
} catch (error) {
  console.error(`执行失败：${error instanceof Error ? error.message : error}`)
  failures.push('执行异常')
} finally {
  if (createdId && api) {
    try {
      await api.request(`/ai/conversations/${createdId}`, { method: 'DELETE' })
      console.log(`      已清理测试会话 #${createdId}`)
    } catch {
      // 忽略清理失败
    }
  }
  await browser?.close()
}

console.log(failures.length === 0 ? '\nAI 助手（含会话列表）验证通过' : `\n${failures.length} 项失败：${failures.join('、')}`)
process.exit(failures.length === 0 ? 0 : 1)

/**
 * 无依赖的 headless 浏览器工具：用 Chrome DevTools Protocol 驱动真实页面，
 * 供 scripts/check-*.mjs 系列做端到端验证。
 */
import { spawn } from 'node:child_process'
import { existsSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const CANDIDATES = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
]

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

export const findBrowser = () => CANDIDATES.find((path) => existsSync(path)) ?? null

const waitForTarget = async (port) => {
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`)
      const targets = await response.json()
      const page = targets.find((target) => target.type === 'page')
      if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl
    } catch {
      // 浏览器还没起来
    }
    await sleep(250)
  }
  throw new Error('浏览器调试端口未就绪')
}

/**
 * 启动浏览器并返回一组操作句柄。
 * port 需与其他脚本岔开，避免复用同一个调试端口。
 */
export const openBrowser = async ({ port = 9333, appUrl = 'about:blank' } = {}) => {
  const binary = findBrowser()
  if (!binary) throw new Error('未找到 Chrome 或 Edge，无法进行浏览器验证')

  const userDataDir = mkdtempSync(join(tmpdir(), 'dsh-chrome-'))
  const chrome = spawn(
    binary,
    [
      '--headless=new',
      '--disable-gpu',
      '--no-first-run',
      '--no-default-browser-check',
      '--no-sandbox',
      '--disable-extensions',
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${userDataDir}`,
      appUrl,
    ],
    { stdio: 'ignore' },
  )

  const socket = new WebSocket(await waitForTarget(port))
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true })
    socket.addEventListener('error', () => reject(new Error('WebSocket 连接失败')), { once: true })
  })

  let nextId = 0
  const pending = new Map()
  const consoleErrors = []

  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data)
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) reject(new Error(message.error.message))
      else resolve(message.result)
      return
    }
    if (message.method === 'Runtime.exceptionThrown') {
      consoleErrors.push(
        message.params.exceptionDetails?.exception?.description ??
          message.params.exceptionDetails?.text ??
          'unknown exception',
      )
    }
    if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') {
      consoleErrors.push(
        message.params.args?.map((arg) => arg.value ?? arg.description).join(' ') ?? 'console.error',
      )
    }
  })

  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = (nextId += 1)
      pending.set(id, { resolve, reject })
      socket.send(JSON.stringify({ id, method, params }))
    })

  const evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    })
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.exception?.description ?? '页面执行失败')
    }
    return result.result.value
  }

  const navigate = async (url) => {
    await send('Page.navigate', { url })
  }

  const waitFor = async (expression, { attempts = 80, interval = 200 } = {}) => {
    for (let attempt = 0; attempt < attempts; attempt += 1) {
      if (await evaluate(expression)) return true
      await sleep(interval)
    }
    return false
  }

  const close = async () => {
    socket.close()
    chrome.kill()
    await sleep(300)
    try {
      rmSync(userDataDir, { recursive: true, force: true })
    } catch {
      // 忽略清理失败
    }
  }

  await send('Runtime.enable')
  await send('Page.enable')

  return { evaluate, send, navigate, waitFor, consoleErrors, close }
}

/** 生成一个调用 Restful 接口的小工具（带 JWT） */
export const apiClient = (baseUrl, token) => {
  const request = async (path, { method = 'GET', body } = {}) => {
    const response = await fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    })
    const text = await response.text()
    try {
      return JSON.parse(text)
    } catch {
      return text
    }
  }
  return { request }
}

/** 读取 localStorage 中的登录态并写入浏览器 */
export const signIn = async (browser, { apiUrl, appOrigin, username, password }) => {
  await browser.navigate(`${appOrigin}/login`)
  const onOrigin = await browser.waitFor(
    `location.origin === '${appOrigin}' && document.readyState !== 'loading'`,
  )
  if (!onOrigin) throw new Error('无法进入前端页面')

  const response = await fetch(`${apiUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  })
  const payload = await response.json()
  const token = payload?.data?.accessToken
  if (!token) throw new Error('登录失败')

  await browser.evaluate(`
    localStorage.setItem('life-workbench-token', ${JSON.stringify(token)});
    localStorage.setItem('life-workbench-user', ${JSON.stringify(JSON.stringify(payload.data.user))});
    'ok'
  `)

  return token
}

/** 统计断言：返回失败的项数 */
export const createChecker = () => {
  const failures = []
  const check = (label, ok, detail) => {
    if (ok) {
      console.log(`ok    ${label}`)
    } else {
      failures.push(label)
      console.log(`FAIL  ${label}${detail !== undefined ? ` → ${detail}` : ''}`)
    }
  }
  return { check, failures }
}

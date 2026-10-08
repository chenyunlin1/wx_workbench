/**
 * 页面截图 + 关键元素字号度量工具（headless Chrome）。
 *
 *   node scripts/screenshot.mjs <路径> <输出png> [视口宽] [视口高]
 *   node scripts/screenshot.mjs /fitness shots/fitness-after.png 1440 900
 *   node scripts/screenshot.mjs /schedule shots/week.png 1440 900 --eval "点击周视图的 JS"
 *
 * 路径可以是 /fitness 这样的前端路由，也可以是完整 URL。
 * --eval 会在页面加载后、截图前执行一段 JS（用来切视图、打开弹窗等）。
 * 会同时打印一组代表元素的 computed font-size，便于对比排版调整。
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { openBrowser, signIn, sleep } from './lib/browser.mjs'

const API = 'http://localhost:3000/api'
const ORIGIN = 'http://localhost:5174'

const argv = process.argv.slice(2)
const evalIndex = argv.indexOf('--eval')
const preScript = evalIndex >= 0 ? argv[evalIndex + 1] : null
const darkMode = argv.includes('--dark')

// 收集位置参数（跳过 --eval 的值与 --dark 开关）
const positional = []
for (let index = 0; index < argv.length; index += 1) {
  const item = argv[index]
  if (item === '--eval') {
    index += 1
    continue
  }
  if (item === '--dark') continue
  positional.push(item)
}

const route = positional[0] ?? '/dashboard'
const output = positional[1] ?? 'shot.png'
const width = Number(positional[2] ?? 1440)
const height = Number(positional[3] ?? 900)

const TARGETS = [
  ['页面主标题', '.page-heading h2'],
  ['页面副标题', '.page-heading span'],
  ['侧栏菜单项', '.nav-menu .el-menu-item'],
  ['统计卡标签', '.summary-card small'],
  ['统计卡数字', '.summary-card strong'],
  ['统计卡备注', '.summary-note'],
  ['卡片标题', '.panel-head h3'],
  ['卡片说明', '.panel-head p'],
  ['列表主标题', '.record-main strong'],
  ['列表副文本', '.record-main span'],
  ['标签胶囊', '.chip'],
  ['按钮', '.el-button'],
  ['输入框', '.el-input__inner, .el-textarea__inner'],
]

const browser = await openBrowser({ port: 9388 })
try {
  await signIn(browser, { apiUrl: API, appOrigin: ORIGIN, username: 'admin', password: 'admin123' })

  if (darkMode) {
    await browser.evaluate(`localStorage.setItem('life-workbench-theme', 'dark'); 'dark'`)
  }

  await browser.send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: false,
  })

  await browser.navigate(route.startsWith('http') ? route : `${ORIGIN}${route}`)
  await sleep(2500)

  if (preScript) {
    await browser.evaluate(preScript)
    await sleep(900)
  }

  mkdirSync(dirname(output), { recursive: true })
  const shot = await browser.send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
  })
  writeFileSync(output, Buffer.from(shot.data, 'base64'))
  console.log(`截图已保存：${output}（视口 ${width}×${height}）`)

  const sizes = await browser.evaluate(`
    (() => {
      const selectors = ${JSON.stringify(TARGETS)}
      return selectors.map(([label, selector]) => {
        const element = document.querySelector(selector)
        if (!element) return { label, size: '—' }
        const style = getComputedStyle(element)
        return { label, size: style.fontSize, lineHeight: style.lineHeight }
      })
    })()
  `)

  console.log('元素                    字号      行高')
  for (const item of sizes) {
    console.log(`${item.label.padEnd(12, '　')} ${String(item.size).padStart(7)}  ${item.lineHeight ?? ''}`)
  }
} finally {
  await browser.close()
}

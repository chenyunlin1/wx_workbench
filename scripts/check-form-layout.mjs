/**
 * 表单布局体检：逐个打开各页面的表单弹窗，检查表单项里的控件有没有没铺满容器。
 *
 *   node scripts/check-form-layout.mjs
 *
 * 背景：Element Plus 的 el-radio-group 默认按内容收缩，如果只给子项写
 * `width: 50%` 而不给容器 `width: 100%`，整组会缩成一半宽度（本项目的
 * 训练强度、物品状态、知识库类型都踩过这个坑）。
 *
 * 判定：控件宽度比表单项可用宽度小 24px 以上即视为可疑。
 * 已知的合理例外（星级评分、纯按钮行）会自动跳过。
 */
import { createChecker, openBrowser, signIn, sleep } from './lib/browser.mjs'

const API = 'http://localhost:3000/api'
const ORIGIN = 'http://localhost:5174'

const CASES = [
  { route: '/fitness', trigger: '记录训练', dialog: '.workout-form-dialog' },
  { route: '/habits', trigger: '新增习惯', dialog: '.habit-form-dialog' },
  { route: '/habits', trigger: '记录体重', dialog: '.health-form-dialog' },
  { route: '/shopping', trigger: '新增物品', dialog: '.shopping-form-dialog' },
  { route: '/collection', trigger: '新增收藏', dialog: '.collection-form-dialog' },
  { route: '/finance', trigger: '记一笔', dialog: '.finance-form-dialog' },
  { route: '/schedule', trigger: '新建日程', dialog: '.schedule-form-dialog' },
  { route: '/ai', trigger: '设置', dialog: '.ai-settings-dialog' },
]

const { check, failures } = createChecker()
const browser = await openBrowser({ port: 9402 })

try {
  await signIn(browser, { apiUrl: API, appOrigin: ORIGIN, username: 'admin', password: 'admin123' })

  for (const item of CASES) {
    await browser.navigate(`${ORIGIN}${item.route}`)
    await sleep(2200)

    const clicked = await browser.evaluate(`
      (() => {
        const button = [...document.querySelectorAll('button')]
          .find((el) => el.innerText.trim().includes(${JSON.stringify(item.trigger)}))
        if (!button) return false
        button.click()
        return true
      })()
    `)

    if (!clicked) {
      check(`${item.route} · ${item.trigger} 能打开弹窗`, false, '未找到触发按钮')
      continue
    }
    await sleep(900)

    const opened = await browser.evaluate(
      `Boolean(document.querySelector(${JSON.stringify(item.dialog)}))`,
    )
    check(`${item.route} · ${item.trigger} 弹窗已打开`, opened)
    if (!opened) continue

    const rows = await browser.evaluate(`
      (() => {
        // 这些控件的默认预期是铺满整行；星级、按钮、开关之类的窄控件不参与判定
        const STRETCHABLE = '.el-input, .el-select, .el-textarea, .el-input-number, .el-radio-group, .el-date-editor, .el-cascader'
        return [...document.querySelectorAll(${JSON.stringify(item.dialog)} + ' .el-form-item')].map((row) => {
          const label = row.querySelector('.el-form-item__label')?.innerText?.trim() || '(无标签)'
          const rowWidth = Math.round(row.getBoundingClientRect().width)
          const controls = [...row.querySelectorAll(STRETCHABLE)]
            .filter((el) => el.offsetParent !== null)
            .map((el) => ({ width: Math.round(el.getBoundingClientRect().width), kind: el.className }))
          return { label, rowWidth, controls }
        })
      })()
    `)

    const problems = rows.filter((row) =>
      row.controls.some(
        (control) => row.rowWidth - control.width > 24 && control.width < row.rowWidth * 0.9,
      ),
    )

    check(
      `${item.route} · ${item.trigger} 表单控件都铺满（${rows.length} 项）`,
      problems.length === 0,
      problems.map((row) => `${row.label}: ${row.controls.map((c) => c.width).join('/')} vs ${row.rowWidth}`).join('；'),
    )
  }
} catch (error) {
  console.error(`执行失败：${error instanceof Error ? error.message : error}`)
  failures.push('执行异常')
} finally {
  await browser.close()
}

console.log(failures.length === 0 ? '\n表单布局检查通过' : `\n${failures.length} 项失败：${failures.join('、')}`)
process.exit(failures.length === 0 ? 0 : 1)

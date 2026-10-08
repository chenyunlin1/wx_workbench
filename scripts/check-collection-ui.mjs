/**
 * 书影音收藏模块的浏览器端验证：
 * 统计卡数字、封面墙、类型筛选、列表视图、新增弹窗与真实新增/删除流程。
 *
 *   node scripts/check-collection-ui.mjs
 *
 * 需要后端(3000)、前端 dev(5174) 与 MySQL 已启动。
 */
import { apiClient, createChecker, openBrowser, signIn, sleep } from './lib/browser.mjs'

const API = 'http://localhost:3000/api'
const ORIGIN = 'http://localhost:5174'
const PORT = 9355

const { check, failures } = createChecker()
let browser = null
let createdId = null

try {
  browser = await openBrowser({ port: PORT })
  const token = await signIn(browser, {
    apiUrl: API,
    appOrigin: ORIGIN,
    username: 'admin',
    password: 'admin123',
  })
  const api = apiClient(API, token)

  const before = await api.request('/collection?pageSize=100')
  const beforeTotal = before.data.total
  console.log(`      起始收藏数量：${beforeTotal}`)

  await browser.navigate(`${ORIGIN}/collection`)
  const ready = await browser.waitFor(
    `Boolean(document.querySelector('.cover-wall .cover-card, .empty-collection'))`,
  )
  check('收藏页面渲染完成', ready === true)

  // ---- 1. 标题与统计 ----
  const heading = await browser.evaluate(
    `document.querySelector('.page-heading')?.innerText?.replace(/\\s+/g, ' ') ?? ''`,
  )
  console.log(`      页面标题：${heading}`)
  check('页面标题正确', heading.includes('书影音收藏'))

  const stats = await browser.evaluate(
    `[...document.querySelectorAll('.stats-grid .stat')].map((el) => el.innerText.replace(/\\s+/g, ' ').trim())`,
  )
  console.log(`      统计卡：${JSON.stringify(stats)}`)
  check('年度统计有 5 个指标', stats.length === 5, String(stats.length))
  check('统计卡包含 5 类标签', ['已完成', '书籍', '影视', '音乐'].every((label) => stats.some((item) => item.includes(label))))

  const statNumbers = stats.map((item) => Number(item.match(/\d+/)?.[0] ?? -1))
  const expectedNumbers = [
    beforeTotal,
    before.data.items.filter((item) => item.status === 'done').length,
    before.data.items.filter((item) => item.type === 'book').length,
    before.data.items.filter((item) => item.type === 'movie').length,
    before.data.items.filter((item) => item.type === 'music').length,
  ]
  check(
    '统计数字与接口一致',
    JSON.stringify(statNumbers) === JSON.stringify(expectedNumbers),
    `${statNumbers.join(',')} vs ${expectedNumbers.join(',')}`,
  )

  // ---- 2. 封面墙 ----
  const wallCards = await browser.evaluate(`document.querySelectorAll('.cover-wall .cover-card').length`)
  check('封面墙卡片数量正确', wallCards === beforeTotal, `${wallCards} vs ${beforeTotal}`)

  const firstCard = await browser.evaluate(`
    (() => {
      const card = document.querySelector('.cover-wall .cover-card')
      return {
        title: card?.querySelector('.cover-title')?.innerText ?? '',
        type: card?.querySelector('.type-badge')?.innerText ?? '',
        status: card?.querySelector('.status-pill')?.innerText ?? '',
        stars: card?.querySelectorAll('.el-rate__icon.is-active').length ?? 0,
      }
    })()
  `)
  console.log(`      首张卡片：${JSON.stringify(firstCard)}`)
  check('卡片显示标题/类型/状态', Boolean(firstCard.title && firstCard.type && firstCard.status))
  check('评分以星星展示', firstCard.stars > 0, String(firstCard.stars))

  // ---- 3. 类型筛选 ----
  await browser.evaluate(`
    [...document.querySelectorAll('.type-tabs .el-radio-button')]
      .find((el) => el.innerText.trim() === '书籍')
      .querySelector('.el-radio-button__inner').click()
    'clicked'
  `)
  await sleep(700)
  const bookCards = await browser.evaluate(`document.querySelectorAll('.cover-wall .cover-card').length`)
  const expectedBooks = before.data.items.filter((item) => item.type === 'book').length
  check('切换到「书籍」后只剩书籍', bookCards === expectedBooks, `${bookCards} vs ${expectedBooks}`)

  // ---- 4. 列表视图 ----
  await browser.evaluate(`
    [...document.querySelectorAll('.view-switch .el-radio-button')]
      .find((el) => el.querySelector('svg')) &&
    [...document.querySelectorAll('.view-switch .el-radio-button')][1]
      .querySelector('.el-radio-button__inner').click()
    'clicked'
  `)
  await sleep(600)
  const rows = await browser.evaluate(`document.querySelectorAll('.record-row').length`)
  check('列表视图渲染出行', rows === expectedBooks, `${rows} vs ${expectedBooks}`)

  const rowDetail = await browser.evaluate(`
    (() => {
      const row = document.querySelector('.record-row')
      const select = row?.querySelector('.status-select')
      return {
        title: row?.querySelector('.record-main strong')?.innerText ?? '',
        status: select?.innerText?.replace(/\\s+/g, ' ').trim() ?? '',
        hasRate: Boolean(row?.querySelector('.record-rate')),
        actions: [...(row?.querySelectorAll('.record-actions button') ?? [])].map((b) => b.innerText.trim()),
      }
    })()
  `)
  console.log(`      列表首行：${JSON.stringify(rowDetail)}`)
  check('列表行包含标题与状态选择', Boolean(rowDetail.title && rowDetail.status))
  check('列表行有编辑/删除按钮', rowDetail.actions.length === 2, rowDetail.actions.join('/'))

  // ---- 5. 新增收藏（真实写入后清理） ----
  const testTitle = `UI 验证条目 ${Date.now().toString().slice(-6)}`
  await browser.evaluate(`
    [...document.querySelectorAll('.filter-right button')]
      .find((el) => el.innerText.includes('新增收藏')).click()
    'clicked'
  `)
  const dialogOpen = await browser.waitFor(`Boolean(document.querySelector('.collection-form-dialog'))`)
  check('新增弹窗可以打开', dialogOpen === true)

  const dialogFields = await browser.evaluate(`
    (() => {
      const dialog = document.querySelector('.collection-form-dialog')
      if (!dialog) return null
      return {
        labels: [...dialog.querySelectorAll('.el-form-item__label')].map((el) => el.innerText.trim()),
        typeButtons: [...dialog.querySelectorAll('.type-option')].map((el) => el.innerText.trim()),
        hasRate: Boolean(dialog.querySelector('.el-rate')),
        textarea: Boolean(dialog.querySelector('textarea')),
        inputs: dialog.querySelectorAll('input').length,
      }
    })()
  `)
  console.log(`      弹窗字段：${JSON.stringify(dialogFields)}`)
  check(
    '弹窗包含需求里的字段',
    ['标题', '类型', '状态', '评分（1-5）', '年份', '封面链接', '短评'].every((label) =>
      dialogFields?.labels?.includes(label),
    ),
    (dialogFields?.labels ?? []).join('/'),
  )
  check('类型可选书籍/影视/音乐', dialogFields?.typeButtons?.slice(0, 3).join('') === '书籍影视音乐')
  check('状态为三种可选按钮', (dialogFields?.typeButtons?.length ?? 0) === 6, String(dialogFields?.typeButtons?.length))
  check('有星级评分控件', dialogFields?.hasRate === true)
  check('有短评输入框', dialogFields?.textarea === true)

  await browser.evaluate(`
    (() => {
      const input = document.querySelector('.collection-form-dialog input')
      input.focus()
      return 'focused'
    })()
  `)
  await browser.send('Input.insertText', { text: testTitle })

  // 先选类型，等状态按钮随类型刷新后再点第三个（已完成）
  await browser.evaluate(`
    [...document.querySelectorAll('.collection-form-dialog .type-option')]
      .find((el) => el.innerText.trim() === '影视').click()
    'type'
  `)
  await sleep(250)
  const statusButtons = await browser.evaluate(
    `[...document.querySelectorAll('.collection-form-dialog .type-option')].map((el) => el.innerText.trim())`,
  )
  console.log(`      弹窗按钮状态：${JSON.stringify(statusButtons)}`)
  check('切换类型后状态文案跟随变化', statusButtons.slice(3).join('/') === '想看/在看/看完', statusButtons.slice(3).join('/'))

  await browser.evaluate(`
    [...document.querySelectorAll('.collection-form-dialog .type-option')].slice(3)[2].click()
    'status'
  `)
  await sleep(150)
  await browser.evaluate(`
    document.querySelector('.collection-form-dialog .save-button').click()
    'submitted'
  `)

  const saved = await browser.waitFor(
    `document.body.innerText.includes('已加入收藏') || !document.querySelector('.collection-form-dialog')`,
    { attempts: 60 },
  )
  check('保存后弹窗关闭并提示成功', saved === true)

  await sleep(800)
  const after = await api.request('/collection?pageSize=100')
  const created = after.data.items.find((item) => item.title === testTitle)
  createdId = created?.id ?? null
  console.log(`      新增记录：${JSON.stringify(created ?? null)}`)
  check('新记录已写入数据库', Boolean(created))
  check('新记录类型与状态正确', created?.type === 'movie' && created?.status === 'done', `${created?.type}/${created?.status}`)

  const statsAfter = await browser.evaluate(
    `[...document.querySelectorAll('.stats-grid .stat')].map((el) => Number(el.innerText.match(/\\d+/)?.[0] ?? -1))`,
  )
  console.log(`      保存后统计卡：${JSON.stringify(statsAfter)}（保存前 ${JSON.stringify(statNumbers)}）`)
  check('保存后年度统计自动刷新', statsAfter[0] === statNumbers[0] + 1 && statsAfter[3] === statNumbers[3] + 1, statsAfter.join(','))
  check('保存后筛选结果未被打乱', (await browser.evaluate(`document.querySelectorAll('.record-row').length`)) === expectedBooks)

  check('页面无 JS 异常', browser.consoleErrors.length === 0, browser.consoleErrors.slice(0, 3).join(' | '))
} catch (error) {
  console.error(`执行失败：${error instanceof Error ? error.message : error}`)
  failures.push('执行异常')
} finally {
  // 清理测试数据
  if (browser) {
    try {
      const token = await browser.evaluate(`localStorage.getItem('life-workbench-token')`)
      if (createdId && token) {
        await apiClient('http://localhost:3000/api', token).request(`/collection/${createdId}`, {
          method: 'DELETE',
        })
        console.log(`      已清理测试条目 #${createdId}`)
      }
    } catch {
      // 忽略清理失败
    }
  }
  await browser?.close()
}

console.log(failures.length === 0 ? '\n书影音收藏模块验证通过' : `\n${failures.length} 项失败：${failures.join('、')}`)
process.exit(failures.length === 0 ? 0 : 1)

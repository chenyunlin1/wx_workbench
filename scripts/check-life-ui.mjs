/**
 * 习惯健康 / 减脂健身 / 待买清单 三个页面的浏览器端验证：
 * 统计数字与接口一致性、打卡切换、弹窗字段、真实新增与清理流程。
 *
 *   node scripts/check-life-ui.mjs
 *
 * 需要后端(3000)、前端 dev(5174) 与 MySQL 已启动。测试产生的数据会在结束时清理。
 */
import { apiClient, createChecker, openBrowser, signIn, sleep } from './lib/browser.mjs'

const API = 'http://localhost:3000/api'
const ORIGIN = 'http://localhost:5174'
const PORT = 9366

const { check, failures } = createChecker()
let browser = null
let token = null
const cleanup = { habits: [], workouts: [] }

const sumText = (value) => `¥${Number(value || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

try {
  browser = await openBrowser({ port: PORT })
  token = await signIn(browser, {
    apiUrl: API,
    appOrigin: ORIGIN,
    username: 'admin',
    password: 'admin123',
  })
  const api = apiClient(API, token)

  /* ---------------- 习惯健康 ---------------- */
  const habitStats = (await api.request('/habits/stats?days=14')).data
  const healthRecords = (await api.request('/health/records')).data
  console.log(`      接口前置数据：习惯 ${habitStats.habits.length} 个，体重记录 ${healthRecords.length} 条`)

  await browser.navigate(`${ORIGIN}/habits`)
  check('习惯健康页面渲染完成', await browser.waitFor(`Boolean(document.querySelector('.habit-grid .habit-card, .empty-block'))`))
  // 等异步数据回来再断言统计数字
  await browser.waitFor(`document.querySelectorAll('.habit-card').length > 0 || document.querySelectorAll('.heat-cell').length > 0`)

  const habitSummary = await browser.evaluate(
    `[...document.querySelectorAll('.summary-grid .summary-card')].map((el) => el.innerText.replace(/\\s+/g, ' ').trim())`,
  )
  console.log(`      概览卡：${JSON.stringify(habitSummary)}`)
  check('概览有 4 张卡片', habitSummary.length === 4, String(habitSummary.length))
  check(
    '今日打卡数字与接口一致',
    habitSummary[0]?.includes(`${habitStats.today.checked}/${habitStats.today.total}`),
    habitSummary[0],
  )
  check(
    '连续天数与接口一致',
    habitSummary[2]?.includes(`${habitStats.longestStreak}天`),
    habitSummary[2],
  )

  const habitCardCount = await browser.evaluate(`document.querySelectorAll('.habit-card').length`)
  check('习惯卡片数量正确', habitCardCount === habitStats.habits.length, `${habitCardCount} vs ${habitStats.habits.length}`)

  const heatCells = await browser.evaluate(`document.querySelectorAll('.heat-strip .base-chart canvas').length`)
  check('打卡分布图表已渲染', heatCells === 1, String(heatCells))

  const weekDots = await browser.evaluate(`document.querySelectorAll('.habit-card:first-child .week-dot').length`)
  check('每个习惯显示最近 7 天', weekDots === 7, String(weekDots))

  check(
    '体重趋势图已渲染（ECharts）',
    await browser.evaluate(`
      (() => {
        const canvas = document.querySelector('.health-chart .base-chart canvas')
        return Boolean(canvas && canvas.width > 0 && canvas.height > 0)
      })()
    `),
  )
  const healthRows = await browser.evaluate(`document.querySelectorAll('.health-row').length`)
  check('体重记录列表有数据', healthRows > 0, String(healthRows))

  // 打卡 / 取消打卡：选择一个当前未打卡的习惯，操作后恢复原状
  const targetIndex = habitStats.habits.findIndex((habit) => !habit.checkedToday)
  if (targetIndex >= 0) {
    const targetName = habitStats.habits[targetIndex].name
    await browser.evaluate(`document.querySelectorAll('.habit-check')[${targetIndex}].click(); 'clicked'`)
    await sleep(1200)
    const afterCheckIn = (await api.request('/habits/stats?days=14')).data
    check(`打卡「${targetName}」后接口状态变为已打卡`, afterCheckIn.habits[targetIndex].checkedToday === true)

    await browser.evaluate(`document.querySelectorAll('.habit-check')[${targetIndex}].click(); 'clicked'`)
    await sleep(1200)
    const afterCancel = (await api.request('/habits/stats?days=14')).data
    check(`取消「${targetName}」打卡后恢复未打卡`, afterCancel.habits[targetIndex].checkedToday === false)
    check(
      '取消打卡后连续天数回到原值',
      afterCancel.habits[targetIndex].streakDays === habitStats.habits[targetIndex].streakDays,
      `${afterCancel.habits[targetIndex].streakDays} vs ${habitStats.habits[targetIndex].streakDays}`,
    )
  } else {
    check('存在可打卡的习惯用于验证', false, '所有习惯今天都已打卡')
  }

  // 新增习惯 → 校验 → 清理
  const habitName = `UI 验证习惯 ${Date.now().toString().slice(-5)}`
  await browser.evaluate(`
    [...document.querySelectorAll('.heading-actions button')].find((el) => el.innerText.includes('新增习惯')).click(); 'open'
  `)
  check('新增习惯弹窗打开', await browser.waitFor(`Boolean(document.querySelector('.habit-form-dialog'))`))
  await browser.evaluate(`
    (() => {
      const input = document.querySelector('.habit-form-dialog input')
      input.focus()
      return 'focus'
    })()
  `)
  await browser.send('Input.insertText', { text: habitName })
  const iconOptions = await browser.evaluate(`document.querySelectorAll('.habit-form-dialog .icon-option').length`)
  check('弹窗提供图标选择', iconOptions >= 8, String(iconOptions))
  await browser.evaluate(`document.querySelector('.habit-form-dialog .save-button').click(); 'save'`)
  await sleep(1400)

  const habitsAfter = (await api.request('/habits')).data
  const createdHabit = habitsAfter.find((habit) => habit.name === habitName)
  check('新习惯已写入数据库', Boolean(createdHabit), habitName)
  if (createdHabit) cleanup.habits.push(createdHabit.id)

  /* ---------------- 减脂健身 ---------------- */
  const workoutStats = (await api.request('/workout/stats?days=7')).data
  console.log(`      接口前置数据：近 7 天训练 ${workoutStats.sessions} 次 / ${workoutStats.duration} 分钟`)

  await browser.navigate(`${ORIGIN}/fitness`)
  check(
    '减脂健身页面渲染完成',
    await browser.waitFor(`Boolean(document.querySelector('.base-chart, .chart-empty, .empty-block'))`),
  )
  await browser.waitFor(`Boolean(document.querySelector('.base-chart canvas'))`)

  const fitnessSummary = await browser.evaluate(
    `[...document.querySelectorAll('.summary-grid .summary-card')].map((el) => el.innerText.replace(/\\s+/g, ' ').trim())`,
  )
  console.log(`      概览卡：${JSON.stringify(fitnessSummary)}`)
  check('概览有 4 张卡片', fitnessSummary.length === 4, String(fitnessSummary.length))
  check('训练次数与接口一致', fitnessSummary[0]?.includes(`${workoutStats.sessions}次`), fitnessSummary[0])
  check('总时长与接口一致', fitnessSummary[1]?.includes(`${workoutStats.duration}分钟`), fitnessSummary[1])
  check('总消耗与接口一致', fitnessSummary[2]?.includes(`${workoutStats.calories}千卡`), fitnessSummary[2])
  check('连续训练天数与接口一致', fitnessSummary[3]?.includes(`${workoutStats.streakDays}天`), fitnessSummary[3])

  const dailyChartLabel = await browser.evaluate(
    `document.querySelector('.panel .base-chart')?.getAttribute('aria-label') ?? ''`,
  )
  console.log(`      训练分布图表：${dailyChartLabel}`)
  check('近 7 天训练分布图表已渲染', dailyChartLabel.includes('近 7 天'), dailyChartLabel)
  check(
    '图表画布尺寸正常',
    await browser.evaluate(`
      (() => {
        const canvas = document.querySelector('.panel .base-chart canvas')
        return Boolean(canvas && canvas.width > 0 && canvas.height > 0)
      })()
    `),
  )
  const typeChart = await browser.evaluate(
    `document.querySelector('.type-chart .base-chart')?.getAttribute('aria-label') ?? ''`,
  )
  check('类型分布图表已渲染', typeChart.includes('类型'), typeChart)
  check('训练页展示体重趋势', await browser.evaluate(`Boolean(document.querySelector('.weight-chart, .base-chart canvas'))`))

  // 记录训练 → 校验 → 清理
  await browser.evaluate(`
    [...document.querySelectorAll('.heading-actions button')].find((el) => el.innerText.includes('记录训练')).click(); 'open'
  `)
  check('记录训练弹窗打开', await browser.waitFor(`Boolean(document.querySelector('.workout-form-dialog'))`))
  const workoutTypeCount = await browser.evaluate(`document.querySelectorAll('.workout-form-dialog .type-option').length`)
  check('弹窗提供 8 种训练类型', workoutTypeCount === 8, String(workoutTypeCount))
  await browser.evaluate(`
    (() => {
      const options = [...document.querySelectorAll('.workout-form-dialog .type-option')]
      options.find((el) => el.innerText.includes('骑行')).click()
      return 'type'
    })()
  `)
  await sleep(200)
  await browser.evaluate(`document.querySelector('.workout-form-dialog .save-button').click(); 'save'`)
  await sleep(1500)

  const workoutsAfter = (await api.request('/workout?pageSize=100')).data
  const createdWorkout = workoutsAfter.items.find((item) => item.type === 'cycling' && item.duration === 30)
  check('新训练记录已写入数据库', Boolean(createdWorkout))
  if (createdWorkout) cleanup.workouts.push(createdWorkout.id)

  const statsAfterWorkout = (await api.request('/workout/stats?days=7')).data
  check('新增后统计次数 +1', statsAfterWorkout.sessions === workoutStats.sessions + 1, `${statsAfterWorkout.sessions} vs ${workoutStats.sessions}`)

  // 切换统计窗口
  await browser.evaluate(`
    [...document.querySelectorAll('.window-switch .el-radio-button')][2].querySelector('.el-radio-button__inner').click(); 'clicked'
  `)
  await sleep(1200)
  const labelAfterSwitch = await browser.evaluate(
    `document.querySelector('.panel .base-chart')?.getAttribute('aria-label') ?? ''`,
  )
  const statsAfterSwitch = (await api.request('/workout/stats?days=30')).data
  check(
    '切换到近 30 天后图表与接口同步',
    labelAfterSwitch.includes('近 30 天') && statsAfterSwitch.daily.length === 30,
    `${labelAfterSwitch} / daily=${statsAfterSwitch.daily.length}`,
  )

  /* ---------------- 待买清单 ---------------- */
  const shoppingBefore = (await api.request('/shopping')).data
  const pendingBefore = shoppingBefore.filter((item) => item.status === 'pending')
  const boughtBefore = shoppingBefore.filter((item) => item.status === 'bought')
  const pendingTotalBefore = pendingBefore.reduce((sum, item) => sum + Number(item.price), 0)
  console.log(`      接口前置数据：待买 ${pendingBefore.length} 件，已买 ${boughtBefore.length} 件`)

  await browser.navigate(`${ORIGIN}/shopping`)
  check('待买清单页面渲染完成', await browser.waitFor(`Boolean(document.querySelector('.item-row, .empty-block'))`))
  await browser.waitFor(`document.querySelectorAll('.item-row').length > 0`)

  const shoppingSummary = await browser.evaluate(
    `[...document.querySelectorAll('.summary-grid .summary-card')].map((el) => el.innerText.replace(/\\s+/g, ' ').trim())`,
  )
  console.log(`      概览卡：${JSON.stringify(shoppingSummary)}`)
  check('概览有 3 张卡片', shoppingSummary.length === 3, String(shoppingSummary.length))
  check('待买件数与接口一致', shoppingSummary[0]?.includes(`${pendingBefore.length}件`), shoppingSummary[0])
  check(
    '待买合计与接口一致',
    shoppingSummary[1]?.includes(sumText(pendingTotalBefore)),
    `${shoppingSummary[1]} vs ${sumText(pendingTotalBefore)}`,
  )

  // 快速添加（回车提交，Vue 监听的是 keyup）
  const quickName = `UI 验证物品 ${Date.now().toString().slice(-5)}`
  await browser.evaluate(`document.querySelector('.quick-inputs input').focus(); 'focus'`)
  await browser.send('Input.insertText', { text: quickName })
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
  await sleep(1400)
  const afterQuickAdd = (await api.request('/shopping')).data
  const createdItem = afterQuickAdd.find((item) => item.name === quickName)
  check('快速添加已写入数据库', Boolean(createdItem), quickName)

  if (createdItem) {
    const rowsAfterAdd = await browser.evaluate(`document.querySelectorAll('.item-row').length`)
    check('列表自动刷新显示新条目', rowsAfterAdd === shoppingBefore.length + 1, `${rowsAfterAdd} vs ${shoppingBefore.length + 1}`)

    // 勾选为已买
    const index = afterQuickAdd.findIndex((item) => item.id === createdItem.id)
    const visibleOrder = await browser.evaluate(
      `[...document.querySelectorAll('.item-row .item-main strong')].map((el) => el.innerText.trim())`,
    )
    const domIndex = visibleOrder.indexOf(quickName)
    check('新条目出现在列表首位', domIndex === 0, `index=${domIndex} total=${index}`)
    await browser.evaluate(`document.querySelectorAll('.item-check input')[0].click(); 'toggle'`)
    await sleep(1200)
    const afterToggle = (await api.request('/shopping')).data
    check(
      '勾选后状态变为已买',
      afterToggle.find((item) => item.id === createdItem.id)?.status === 'bought',
    )

    // 通过界面删除（顺带验证确认框）
    await browser.evaluate(`
      (() => {
        const row = document.querySelector('.item-row')
        const button = [...row.querySelectorAll('.item-actions button')].find((el) => el.innerText.includes('删除'))
        button.click()
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
    const afterDelete = (await api.request('/shopping')).data
    check('界面删除后记录已移除', !afterDelete.some((item) => item.id === createdItem.id))
  }

  check('页面无 JS 异常', browser.consoleErrors.length === 0, browser.consoleErrors.slice(0, 3).join(' | '))
} catch (error) {
  console.error(`执行失败：${error instanceof Error ? error.message : error}`)
  failures.push('执行异常')
} finally {
  // 清理测试数据
  if (token) {
    const api = apiClient(API, token)
    for (const id of cleanup.habits) await api.request(`/habits/${id}`, { method: 'DELETE' })
    for (const id of cleanup.workouts) await api.request(`/workout/${id}`, { method: 'DELETE' })
    if (cleanup.habits.length || cleanup.workouts.length) {
      console.log(`      已清理测试数据：习惯 ${cleanup.habits.length} 条、训练 ${cleanup.workouts.length} 条`)
    }
  }
  await browser?.close()
}

console.log(
  failures.length === 0 ? '\n习惯健康 / 减脂健身 / 待买清单 验证通过' : `\n${failures.length} 项失败：${failures.join('、')}`,
)
process.exit(failures.length === 0 ? 0 : 1)

/**
 * 复现并验证 Pinia/Vue 的响应式陷阱：
 * 往 reactive 数组里 push 原始对象后，如果继续改「原始对象」，不会触发任何更新；
 * 只有通过数组返回的 proxy 去改，才会触发依赖它的组件/侦听器。
 *
 *   node scripts/check-reactivity.mjs
 */
import { effect, reactive } from '@vue/reactivity'

const state = reactive({ messages: [] })

let renders = 0
let snapshot = ''

effect(() => {
  renders += 1
  snapshot = state.messages.length ? state.messages[0].content : ''
})

const pushMessage = () => {
  state.messages.length = 0
  renders = 0
  snapshot = ''
  return { id: 'a', content: '', status: 'streaming' }
}

let failures = 0
const check = (label, condition, detail) => {
  if (condition) {
    console.log(`ok    ${label}`)
  } else {
    failures += 1
    console.log(`FAIL  ${label}${detail ? ` → ${detail}` : ''}`)
  }
}

// ---- 反例：改原始对象（旧实现） ----
const raw = pushMessage()
state.messages.push(raw)
const rendersAfterPush = renders

raw.content += '你好'
raw.content += '，世界'
check(
  '改原始对象不会触发更新（这正是 bug 的表现）',
  renders === rendersAfterPush && snapshot === '',
  `renders=${renders} snapshot="${snapshot}"`,
)

// ---- 正解：改 proxy（修复后的实现） ----
const raw2 = pushMessage()
state.messages.push(raw2)
const proxy = state.messages[state.messages.length - 1]
const rendersBeforeProxy = renders

proxy.content += '你好'
const afterFirst = renders
proxy.content += '，世界'

check('改 proxy 会触发更新', afterFirst > rendersBeforeProxy, `renders=${renders}`)
check('proxy 与原始对象是同一份数据', raw2.content === '你好，世界', `raw2.content="${raw2.content}"`)
check('侦听器看到最终内容', snapshot === '你好，世界', `snapshot="${snapshot}"`)

// ---- 通过下标每次重新读取 proxy，同样可行 ----
const raw3 = pushMessage()
state.messages.push(raw3)
const rendersBeforeIndex = renders
const index = state.messages.length - 1
state.messages[index].content += 'A'
state.messages[index].content += 'B'
check('按下标访问同样触发更新', renders > rendersBeforeIndex, `renders=${renders}`)
check('下标写法数据一致', raw3.content === 'AB', `raw3.content="${raw3.content}"`)

console.log(failures === 0 ? '\n结论：必须先拿到 proxy 再改，直接改原始对象不会回显。' : `\n${failures} 项失败`)
process.exit(failures === 0 ? 0 : 1)

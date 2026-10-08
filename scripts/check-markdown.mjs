import { renderMarkdown } from '../frontend/src/utils/markdown.ts'

const cases = [
  ['HTML 注入应被转义', '<img src=x onerror="alert(1)"> 你好'],
  ['script 标签应被转义', '<script>alert(1)</script>'],
  ['javascript: 链接不应生成 a 标签', '[点我](javascript:alert(1))'],
  ['正常 https 链接', '见 [DeepSeek](https://platform.deepseek.com) 文档'],
  ['裸链接', '文档在 https://api.deepseek.com 这里'],
  ['标题与列表', '## 今日安排\n- 09:30 项目同步\n- 14:00 接口联调\n1. 第一项\n2. 第二项'],
  ['表格', '| 项目 | 数值 |\n| --- | --- |\n| 结余 | 14120.00 元 |'],
  ['代码块内的 HTML 不应生效', '```html\n<b>bold</b>\n```'],
  ['行内代码中的星号不解析', '参数 `**not bold**` 保持原样'],
  ['加粗与斜体', '这是 **重点** 和 *斜体*，还有 ~~删除~~'],
  ['引用与分隔线', '> 数据中没有相关记录\n\n---\n\n结束'],
  ['段落换行', '第一行\n第二行'],
]

let failures = 0
const check = (label, condition) => {
  if (!condition) {
    failures += 1
    console.log(`FAIL  ${label}`)
  } else {
    console.log(`ok    ${label}`)
  }
}

const escaped = renderMarkdown(cases[0][1])
check('转义 <img> 尖括号', escaped.includes('&lt;img') && !escaped.includes('<img'))
check('转义 onerror 属性引号', escaped.includes('&quot;alert(1)&quot;'))

const script = renderMarkdown(cases[1][1])
check('转义 <script>', !script.includes('<script'))

const jsLink = renderMarkdown(cases[2][1])
check('javascript: 不生成链接', !jsLink.includes('<a') && jsLink.includes('javascript:'))

const mdLink = renderMarkdown(cases[3][1])
check('https 链接生成 a 标签', mdLink.includes('href="https://platform.deepseek.com"'))
check('外链带 noopener', mdLink.includes('rel="noopener noreferrer"'))

const bare = renderMarkdown(cases[4][1])
check('裸链接自动识别', bare.includes('<a class="md-link" href="https://api.deepseek.com"'))

const lists = renderMarkdown(cases[5][1])
check('h2 降级为 h4', lists.includes('<h4>今日安排</h4>'))
check('无序列表', lists.includes('<ul>') && lists.includes('<li>09:30 项目同步</li>'))
check('有序列表', lists.includes('<ol>') && lists.includes('<li>第一项</li>'))

const table = renderMarkdown(cases[6][1])
check('表格表头', table.includes('<th>项目</th>') && table.includes('<th>数值</th>'))
check('表格数据行', table.includes('<td>结余</td>') && table.includes('<td>14120.00 元</td>'))

const fence = renderMarkdown(cases[7][1])
check('代码块包裹 pre/code', fence.includes('<pre class="md-pre">') && fence.includes('&lt;b&gt;bold&lt;/b&gt;'))
check('代码块内容不再生成标签', !fence.includes('<b>bold</b>'))

const inlineCode = renderMarkdown(cases[8][1])
check('行内代码保留星号', inlineCode.includes('<code class="md-code">**not bold**</code>'))
check('行内代码不生成 strong', !inlineCode.includes('<strong>'))

const emphasis = renderMarkdown(cases[9][1])
check('加粗', emphasis.includes('<strong>重点</strong>'))
check('斜体', emphasis.includes('<em>斜体</em>'))
check('删除线', emphasis.includes('<del>删除</del>'))

const quote = renderMarkdown(cases[10][1])
check('引用块', quote.includes('<blockquote>'))
check('分隔线', quote.includes('<hr />'))
check('引用内容未生成链接', !quote.includes('<a '))

const multiline = renderMarkdown(cases[11][1])
check('段落内换行转 br', multiline.includes('<p>第一行<br />第二行</p>'))

console.log(failures === 0 ? '\n全部通过' : `\n${failures} 项失败`)
process.exit(failures === 0 ? 0 : 1)

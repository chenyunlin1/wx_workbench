/**
 * 极简 Markdown 渲染器：先把原文转义，再生成受控的 HTML 标签，
 * 因此模型输出的任何 HTML 都不会被注入到页面里。
 */

const escapeHtml = (input: string) =>
  input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')

const CODE_PLACEHOLDER = /^\u0000B(\d+)\u0000$/
const CODE_PLACEHOLDER_GLOBAL = /\u0000B(\d+)\u0000/g

const HEADING = /^(#{1,6})\s+(.*)$/
const BULLET = /^[-*+]\s+(.*)$/
const ORDERED = /^\d+[.)]\s+(.*)$/
const HORIZONTAL_RULE = /^(-{3,}|\*{3,}|_{3,})$/
const QUOTE = /^&gt;\s?(.*)$/
const TABLE_SEPARATOR = /^\|?[\s:|-]+\|?$/

const splitRow = (line: string) =>
  line
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((cell) => cell.trim())

export const renderMarkdown = (raw: string): string => {
  if (!raw) return ''

  const placeholders: string[] = []
  const store = (html: string) => {
    const index = placeholders.push(html) - 1
    return `\u0000B${index}\u0000`
  }

  let text = raw.replace(/\u0000/g, '')

  // 1. 代码块先抽出来，避免内部内容被继续解析
  text = text.replace(/```([^\n`]*)\n?([\s\S]*?)```/g, (_match, lang: string, code: string) => {
    const language = lang.trim()
    const label = language ? `<span class="md-lang">${escapeHtml(language)}</span>` : ''
    return store(
      `<pre class="md-pre">${label}<code>${escapeHtml(code.replace(/\n$/, ''))}</code></pre>`,
    )
  })

  // 2. 转义剩下的文本
  text = escapeHtml(text)

  // 3. 行内代码
  text = text.replace(/`([^`\n]+)`/g, (_match, code: string) =>
    store(`<code class="md-code">${code}</code>`),
  )

  // 4. 行内样式与链接
  text = text
    .replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*\w])\*([^*\n]+)\*/g, '$1<em>$2</em>')
    .replace(/~~([^~\n]+)~~/g, '<del>$1</del>')
    .replace(
      /\[([^\]\n]+)\]\((https?:\/\/[^\s)]+)\)/g,
      '<a class="md-link" href="$2" target="_blank" rel="noopener noreferrer">$1</a>',
    )
    .replace(
      /(^|[\s(])(https?:\/\/[^\s<)]+)/g,
      '$1<a class="md-link" href="$2" target="_blank" rel="noopener noreferrer">$2</a>',
    )

  // 5. 块级结构
  const lines = text.split('\n')
  const html: string[] = []
  let paragraph: string[] = []
  let listType: 'ul' | 'ol' | null = null
  let inQuote = false

  const flushParagraph = () => {
    if (!paragraph.length) return
    html.push(`<p>${paragraph.join('<br />')}</p>`)
    paragraph = []
  }
  const closeList = () => {
    if (!listType) return
    html.push(`</${listType}>`)
    listType = null
  }
  const closeQuote = () => {
    if (!inQuote) return
    html.push('</blockquote>')
    inQuote = false
  }
  const breakBlocks = () => {
    flushParagraph()
    closeList()
    closeQuote()
  }

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim()

    if (!line) {
      breakBlocks()
      continue
    }

    if (CODE_PLACEHOLDER.test(line)) {
      breakBlocks()
      html.push(line)
      continue
    }

    const heading = HEADING.exec(line)
    if (heading) {
      breakBlocks()
      const level = Math.min(heading[1].length + 2, 6)
      html.push(`<h${level}>${heading[2]}</h${level}>`)
      continue
    }

    if (HORIZONTAL_RULE.test(line)) {
      breakBlocks()
      html.push('<hr />')
      continue
    }

    // 表格：当前行含 |，下一行是分隔行
    if (line.includes('|') && lines[index + 1] && TABLE_SEPARATOR.test(lines[index + 1].trim())) {
      breakBlocks()
      const head = splitRow(line)
      const rows: string[][] = []
      let cursor = index + 2
      while (cursor < lines.length && lines[cursor].includes('|') && lines[cursor].trim()) {
        rows.push(splitRow(lines[cursor].trim()))
        cursor += 1
      }
      const headHtml = head.map((cell) => `<th>${cell}</th>`).join('')
      const bodyHtml = rows
        .map((row) => `<tr>${head.map((_cell, i) => `<td>${row[i] ?? ''}</td>`).join('')}</tr>`)
        .join('')
      html.push(
        `<div class="md-table-wrap"><table class="md-table"><thead><tr>${headHtml}</tr></thead><tbody>${bodyHtml}</tbody></table></div>`,
      )
      index = cursor - 1
      continue
    }

    const bullet = BULLET.exec(line)
    const ordered = ORDERED.exec(line)
    if (bullet || ordered) {
      flushParagraph()
      closeQuote()
      const nextType = bullet ? 'ul' : 'ol'
      if (listType !== nextType) {
        closeList()
        html.push(`<${nextType}>`)
        listType = nextType
      }
      html.push(`<li>${bullet ? bullet[1] : ordered![1]}</li>`)
      continue
    }

    const quote = QUOTE.exec(line)
    if (quote) {
      flushParagraph()
      closeList()
      if (!inQuote) {
        html.push('<blockquote>')
        inQuote = true
      }
      html.push(`<p>${quote[1]}</p>`)
      continue
    }

    closeList()
    paragraph.push(line)
  }

  breakBlocks()

  return html
    .join('\n')
    .replace(CODE_PLACEHOLDER_GLOBAL, (_match, index: string) => placeholders[Number(index)] ?? '')
}

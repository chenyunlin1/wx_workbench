import { AppAppearance } from '../model/AppAppearance'

/**
 * AI 回复的轻量 markdown 渲染。鸿蒙这个 SDK 版本没有内置 Markdown 组件，
 * 行内语法拆成 Span 交给 Text 排版：加粗、行内代码、列表、引用、标题、链接。
 * 表格在 Text 里排不了，所以文本之上再切一层块：文本块走 Span，表格/分隔线单独成型。
 */
export class MdSpan {
  text: string = ''
  bold: boolean = false
  code: boolean = false
  size: number = 14
  color: string = ''
}

/** 表格：表头和每行都是「单元格 → 行内 Span 列表」 */
export class MdTable {
  header: MdSpan[][] = []
  rows: MdSpan[][][] = []
}

/** 消息切块结果：kind 为 text / table / divider，table 仅表格块有效 */
export class MdBlock {
  kind: string = 'text'
  spans: MdSpan[] = []
  table: MdTable = new MdTable()
}

/** 链接色跟随主题色；Span 只吃字符串色值，所以这里读当前强调色的 hex。 */
function brandHex(): string {
  const accent: string = AppAppearance.current.accent
  return accent.length > 0 ? accent : AppAppearance.defaultAccent
}

/** 引用块文字色：Span 只吃 hex，按深浅模式取一档静态灰。 */
function themeQuoteHex(): string {
  const mode = AppStorage.get<string>('colorMode')
  return mode === 'light' ? '#7A7A7A' : '#9BA0A8'
}

function makeSpan(text: string, bold: boolean, code: boolean, size: number, color: string): MdSpan {
  const item = new MdSpan()
  item.text = text
  item.bold = bold
  item.code = code
  item.size = size
  item.color = color
  return item
}

function pushPlain(target: MdSpan[], text: string, bold: boolean, size: number, color: string): void {
  if (text.length > 0) {
    target.push(makeSpan(text, bold, false, size, color))
  }
}

function trimLeft(text: string): string {
  let result = text
  while (result.length > 0 && (result.charAt(0) === ' ' || result.charAt(0) === '\t')) {
    result = result.substring(1)
  }
  return result
}

function pushInline(target: MdSpan[], raw: string, bold: boolean, size: number, color: string): void {
  let buffer = ''
  let index = 0
  while (index < raw.length) {
    const ch = raw.charAt(index)

    if (ch === '*' && raw.charAt(index + 1) === '*') {
      const end = raw.indexOf('**', index + 2)
      if (end > index + 1) {
        pushPlain(target, buffer, bold, size, color)
        buffer = ''
        pushInline(target, raw.substring(index + 2, end), true, size, color)
        index = end + 2
        continue
      }
    }

    if (ch === '*' && raw.charAt(index + 1) !== '*') {
      const end = raw.indexOf('*', index + 1)
      if (end > index + 1) {
        pushPlain(target, buffer, bold, size, color)
        buffer = ''
        pushPlain(target, raw.substring(index + 1, end), true, size, color)
        index = end + 1
        continue
      }
    }

    if (ch === '`') {
      const end = raw.indexOf('`', index + 1)
      if (end > index) {
        pushPlain(target, buffer, bold, size, color)
        buffer = ''
        target.push(makeSpan(raw.substring(index + 1, end), bold, true, size, color))
        index = end + 1
        continue
      }
    }

    if (ch === '[') {
      const close = raw.indexOf('](', index + 1)
      const tail = close > index ? raw.indexOf(')', close + 2) : -1
      if (close > index && tail > close) {
        pushPlain(target, buffer, bold, size, color)
        buffer = ''
        pushPlain(target, raw.substring(index + 1, close), bold, size, brandHex())
        index = tail + 1
        continue
      }
    }

    buffer += ch
    index += 1
  }
  pushPlain(target, buffer, bold, size, color)
}

/** 连续空行压成一个，首尾空行丢掉，段落间距才稳定 */
function normalize(raw: string): string {
  const lines = raw.split('\n')
  const kept: string[] = []
  let previousBlank = true
  for (const line of lines) {
    if (line.trim().length === 0) {
      if (!previousBlank && kept.length > 0) {
        kept.push('')
      }
      previousBlank = true
      continue
    }
    kept.push(line)
    previousBlank = false
  }
  while (kept.length > 0 && kept[kept.length - 1].trim().length === 0) {
    kept.pop()
  }
  return kept.join('\n')
}

export function parseMarkdown(raw: string, baseSize: number): MdSpan[] {
  const spans: MdSpan[] = []
  const body = normalize(raw)
  if (body.length === 0) {
    return spans
  }
  const lines = body.split('\n')
  let inFence = false

  for (const line of lines) {
    if (trimLeft(line).startsWith('```')) {
      inFence = !inFence
      continue
    }
    if (inFence) {
      spans.push(makeSpan(line, false, true, baseSize - 1, ''))
      spans.push(makeSpan('\n', false, false, baseSize, ''))
      continue
    }

    let text = line
    let indent = 0
    while (text.length > 0 && (text.charAt(0) === ' ' || text.charAt(0) === '\t')) {
      text = text.substring(1)
      indent += 1
    }

    let bold = false
    let size = baseSize
    let color = ''

    if (text.startsWith('#')) {
      let level = 0
      while (text.startsWith('#')) {
        text = text.substring(1)
        level += 1
      }
      text = trimLeft(text)
      bold = true
      size = baseSize + (level <= 1 ? 3 : level === 2 ? 2 : 1)
    }

    if (text.startsWith('> ')) {
      text = text.substring(2)
      color = themeQuoteHex()
    }

    if (text.startsWith('- ') || text.startsWith('* ')) {
      text = '· ' + text.substring(2)
    }

    const parts: MdSpan[] = []
    pushInline(parts, text, bold, size, color)
    if (indent > 0) {
      let pad = ''
      for (let i = 0; i < indent && i < 6; i++) {
        pad += ' '
      }
      parts.unshift(makeSpan(pad, false, false, size, color))
    }
    for (const item of parts) {
      spans.push(item)
    }
    // 换行单独成一个 span：code 才有底色，挂在内容 span 上会把底色涂到行尾
    spans.push(makeSpan('\n', false, false, size, ''))
  }

  return spans
}

/** 单元格内的行内语法（加粗/代码/链接），不处理块级标记 */
export function parseInline(raw: string, size: number, bold: boolean, color: string): MdSpan[] {
  const spans: MdSpan[] = []
  pushInline(spans, raw, bold, size, color)
  return spans
}

/** `| a | b |` → ['a', 'b']；首尾竖线是外框不算单元格，行内代码里的 | 也不拆列 */
function splitCells(line: string): string[] {
  let text = line.trim()
  if (text.startsWith('|')) {
    text = text.substring(1)
  }
  if (text.endsWith('|')) {
    text = text.substring(0, text.length - 1)
  }
  const cells: string[] = []
  let buffer = ''
  let inCode = false
  let i = 0
  while (i < text.length) {
    const ch = text.charAt(i)
    if (ch === '\\' && text.charAt(i + 1) === '|') {
      buffer += '|'
      i += 2
      continue
    }
    if (ch === '`') {
      inCode = !inCode
      buffer += ch
      i += 1
      continue
    }
    if (ch === '|' && !inCode) {
      cells.push(buffer.trim())
      buffer = ''
      i += 1
      continue
    }
    buffer += ch
    i += 1
  }
  cells.push(buffer.trim())
  return cells
}

/** 表格分隔行里的格子：--- 或 :--- 或 ---: 或 :---:，至少两个短横 */
function isDashCell(cell: string): boolean {
  let text = cell
  if (text.startsWith(':')) {
    text = text.substring(1)
  }
  if (text.endsWith(':')) {
    text = text.substring(0, text.length - 1)
  }
  if (text.length < 2) {
    return false
  }
  for (let i = 0; i < text.length; i++) {
    if (text.charAt(i) !== '-') {
      return false
    }
  }
  return true
}

/** 独立成行的 --- / *** / ___ 当作分隔线 */
function isDividerLine(line: string): boolean {
  const text = line.trim()
  if (text.length < 3) {
    return false
  }
  const ch = text.charAt(0)
  if (ch !== '-' && ch !== '*' && ch !== '_') {
    return false
  }
  for (let i = 0; i < text.length; i++) {
    if (text.charAt(i) !== ch) {
      return false
    }
  }
  return true
}

/** 表格起手两行：本行带 |，下一行是 |---| 这类分隔行 */
function isTableStart(lines: string[], index: number): boolean {
  if (index + 1 >= lines.length) {
    return false
  }
  if (lines[index].indexOf('|') < 0 || lines[index + 1].indexOf('|') < 0) {
    return false
  }
  const seps = splitCells(lines[index + 1])
  if (seps.length === 0) {
    return false
  }
  for (const cell of seps) {
    if (!isDashCell(cell)) {
      return false
    }
  }
  return true
}

function parseTableCells(line: string, size: number, bold: boolean): MdSpan[][] {
  const raw = splitCells(line)
  const cells: MdSpan[][] = []
  for (const cell of raw) {
    cells.push(parseInline(cell, size, bold, ''))
  }
  return cells
}

/**
 * 按空行/表格/分隔线把消息切成块。文本块仍复用 parseMarkdown（代码围栏、标题、
 * 列表都留在里面），表格识别在围栏外进行，代码里的 | 不会被当成表格。
 */
export function parseBlocks(raw: string, baseSize: number): MdBlock[] {
  const blocks: MdBlock[] = []
  let chunk: string[] = []
  let inFence = false

  const flushChunk = (): void => {
    if (chunk.length === 0) {
      return
    }
    const spans = parseMarkdown(chunk.join('\n'), baseSize)
    chunk = []
    if (spans.length > 0) {
      const block = new MdBlock()
      block.spans = spans
      blocks.push(block)
    }
  }

  const lines = raw.split('\n')
  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    if (line.trim().startsWith('```')) {
      inFence = !inFence
      chunk.push(line)
      i += 1
      continue
    }
    if (inFence) {
      chunk.push(line)
      i += 1
      continue
    }

    if (isTableStart(lines, i)) {
      flushChunk()
      const header = parseTableCells(lines[i], baseSize - 2, true)
      i += 2
      const rows: MdSpan[][][] = []
      while (i < lines.length) {
        const rowLine = lines[i]
        if (rowLine.trim().length === 0 || rowLine.indexOf('|') < 0) {
          break
        }
        if (rowLine.trim().startsWith('```')) {
          break
        }
        rows.push(parseTableCells(rowLine, baseSize - 2, false))
        i += 1
      }
      // 行比表头多/少的列都补齐到最大列数，表格左右边界才齐
      let width = header.length
      for (const row of rows) {
        if (row.length > width) {
          width = row.length
        }
      }
      while (header.length < width) {
        header.push([])
      }
      for (const row of rows) {
        while (row.length < width) {
          row.push([])
        }
      }
      const table = new MdTable()
      table.header = header
      table.rows = rows
      const block = new MdBlock()
      block.kind = 'table'
      block.table = table
      blocks.push(block)
      continue
    }

    if (isDividerLine(line)) {
      flushChunk()
      const block = new MdBlock()
      block.kind = 'divider'
      blocks.push(block)
      i += 1
      continue
    }

    // 空行切段：段落各自成块，块间距交给外层 Column 的 space
    if (line.trim().length === 0) {
      flushChunk()
      i += 1
      continue
    }

    chunk.push(line)
    i += 1
  }
  flushChunk()

  return blocks
}

/** 单元格内容签名，流式刷新时 ForEach key 要跟着内容走 */
export function mdCellSignature(cell: MdSpan[]): string {
  let sig = ''
  for (const span of cell) {
    sig += span.text
  }
  return sig
}

export function mdRowSignature(row: MdSpan[][]): string {
  let sig = ''
  for (const cell of row) {
    sig += mdCellSignature(cell) + '|'
  }
  return sig
}

export function mdBlockSignature(block: MdBlock): string {
  if (block.kind === 'table') {
    let sig = 't' + mdRowSignature(block.table.header)
    for (const row of block.table.rows) {
      sig += '#' + mdRowSignature(row)
    }
    return sig
  }
  if (block.kind === 'divider') {
    return 'hr'
  }
  let sig = 'p'
  for (const span of block.spans) {
    sig += span.text
  }
  return sig
}

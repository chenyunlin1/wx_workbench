import { AppAppearance } from '../model/AppAppearance'

/**
 * AI 回复的轻量 markdown 渲染。鸿蒙这个 SDK 版本没有内置 Markdown 组件，
 * 所以把常见语法拆成 Span，交给 Text 容器排版：加粗、行内代码、列表、引用、标题、链接。
 */
export class MdSpan {
  text: string = ''
  bold: boolean = false
  code: boolean = false
  size: number = 14
  color: string = ''
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

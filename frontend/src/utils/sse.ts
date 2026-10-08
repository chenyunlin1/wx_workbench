export interface SseFrame {
  event: string
  data: string
}

/**
 * 解析单个 SSE 帧，形如：
 *   event: delta
 *   data: {"content":"..."}
 * 注释行（以 : 开头）会被忽略。
 */
export const parseSseFrame = (raw: string): SseFrame | null => {
  let event = 'message'
  const dataLines: string[] = []

  for (const line of raw.split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith(':')) continue
    if (trimmed.startsWith('event:')) event = trimmed.slice(6).trim()
    else if (trimmed.startsWith('data:')) dataLines.push(trimmed.slice(5).trim())
  }

  if (!dataLines.length) return null
  return { event, data: dataLines.join('\n') }
}

/**
 * 从缓冲区里切出完整帧，并返回尚未收全的半截数据。
 * 网络分片可能把一帧切成几段，所以必须由调用方把 rest 传回下一次解析。
 */
export const parseSseChunk = (buffer: string): { frames: SseFrame[]; rest: string } => {
  const normalized = buffer.replace(/\r\n/g, '\n')
  const parts = normalized.split('\n\n')
  const rest = parts.pop() ?? ''

  const frames: SseFrame[] = []
  for (const part of parts) {
    const frame = parseSseFrame(part)
    if (frame) frames.push(frame)
  }

  return { frames, rest }
}

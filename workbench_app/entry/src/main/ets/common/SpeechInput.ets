import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { audio } from '@kit.AudioKit'
import { speechRecognizer } from '@kit.CoreSpeechKit'

const MIC: Permissions = 'ohos.permission.MICROPHONE'
/** 离线引擎要求每次写入 640 或 1280 字节；16k/16bit/单声道下 1280 字节正好是 40ms */
const CHUNK_BYTES = 1280
/** 长按录音上限，超过后自动收尾，避免一直占着麦克风 */
const MAX_RECORD_MS = 60000

export type TextSink = (text: string, isFinal: boolean) => void
export type EndSink = (message: string) => void

class EngineListener implements speechRecognizer.RecognitionListener {
  private owner: SpeechInput

  constructor(owner: SpeechInput) {
    this.owner = owner
  }

  onStart(sessionId: string, eventMessage: string): void {
    this.owner.onEngineStart()
  }

  onEvent(sessionId: string, eventCode: number, eventMessage: string): void {
  }

  onResult(sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void {
    this.owner.onEngineResult(result.result, result.isFinal)
  }

  onComplete(sessionId: string, eventMessage: string): void {
    this.owner.onEngineEnd('')
  }

  onError(sessionId: string, errorCode: number, errorMessage: string): void {
    this.owner.onEngineEnd('语音识别失败（' + errorCode + '）')
  }
}

/**
 * 离线语音转文字：AudioCapturer 采集 PCM 喂给 CoreSpeechKit 的识别引擎。
 * 只负责识别，输入框由调用方持有，所以随时可以中断而不丢已识别的文字。
 */
export class SpeechInput {
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null
  private capturer: audio.AudioCapturer | null = null
  private sessionId: string = ''
  private pending: Uint8Array = new Uint8Array(0)
  private listening: boolean = false
  private finishing: boolean = false
  private textSink: TextSink | null = null
  private endSink: EndSink | null = null
  private timer: number = -1
  recording: boolean = false

  static async requestMic(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const result = await atManager.requestPermissionsFromUser(context, [MIC])
      const auth: number[] = result.authResults
      return auth.length > 0 && auth[0] === 0
    } catch (err) {
      return false
    }
  }

  async start(onText: TextSink, onEnd: EndSink): Promise<void> {
    if (this.recording) {
      return
    }
    this.textSink = onText
    this.endSink = onEnd
    this.sessionId = 'lifeos' + Date.now().toString()
    this.pending = new Uint8Array(0)
    this.listening = false
    this.finishing = false

    const extra: Record<string, Object> = {
      'locate': 'CN',
      'recognizerMode': 'short'
    }
    const createParams: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
      extraParams: extra
    }
    const engine = await speechRecognizer.createEngine(createParams)
    engine.setListener(new EngineListener(this))

    const audioInfo: speechRecognizer.AudioInfo = {
      audioType: 'pcm',
      sampleRate: 16000,
      soundChannel: 1,
      sampleBit: 16
    }
    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: audioInfo
    }
    engine.startListening(startParams)

    const options: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
    }
    try {
      const capturer = await audio.createAudioCapturer(options)
      capturer.on('readData', (buffer: ArrayBuffer) => {
        this.feed(buffer)
      })
      await capturer.start()
      this.engine = engine
      this.capturer = capturer
      this.recording = true
      this.timer = setTimeout(() => {
        this.stop()
      }, MAX_RECORD_MS)
    } catch (err) {
      engine.shutdown()
      this.textSink = null
      this.endSink = null
      throw new Error('无法打开麦克风，请检查录音权限')
    }
  }

  /** 收尾：停止采集并让引擎把剩余音频识别完，结果仍会通过 onText 回调 */
  stop(): void {
    if (!this.recording) {
      return
    }
    this.recording = false
    this.clearTimer()
    this.finishing = true
    this.stopCapturer()
    const engine = this.engine
    if (engine === null) {
      return
    }
    if (!this.listening) {
      // 引擎没起来就别再等回调了，直接把输入框交还给调用方
      try {
        engine.cancel(this.sessionId)
      } catch (err) {
      }
      this.onEngineEnd('语音识别没有响应，请重试或直接输入')
      return
    }
    this.flushTail(engine)
    try {
      engine.finish(this.sessionId)
    } catch (err) {
      this.onEngineEnd('语音识别结束失败')
    }
  }

  /** 立即放弃本次识别，不会再收到结果 */
  cancel(): void {
    this.recording = false
    this.clearTimer()
    const engine = this.engine
    if (engine !== null) {
      try {
        engine.cancel(this.sessionId)
      } catch (err) {
      }
    }
    this.stopCapturer()
    this.releaseEngine()
    this.textSink = null
    this.endSink = null
  }

  onEngineStart(): void {
    this.listening = true
  }

  onEngineResult(text: string, isFinal: boolean): void {
    const sink = this.textSink
    if (sink !== null) {
      sink(text, isFinal)
    }
  }

  onEngineEnd(message: string): void {
    this.stopCapturer()
    this.releaseEngine()
    this.recording = false
    this.clearTimer()
    const sink = this.endSink
    this.textSink = null
    this.endSink = null
    if (sink !== null) {
      sink(message)
    }
  }

  private feed(buffer: ArrayBuffer): void {
    const engine = this.engine
    if (engine === null) {
      return
    }
    const incoming = new Uint8Array(buffer)
    const merged = new Uint8Array(this.pending.length + incoming.length)
    merged.set(this.pending, 0)
    merged.set(incoming, this.pending.length)
    let offset = 0
    if (this.listening && !this.finishing) {
      while (merged.length - offset >= CHUNK_BYTES) {
        try {
          engine.writeAudio(this.sessionId, merged.subarray(offset, offset + CHUNK_BYTES))
        } catch (err) {
          // 会话已经不在接收状态，丢掉残余即可
          this.pending = new Uint8Array(0)
          return
        }
        offset += CHUNK_BYTES
      }
    }
    this.pending = merged.subarray(offset)
  }

  /** 不足一片的尾巴补静音写进去，否则最后几十毫秒的发音会被丢掉 */
  private flushTail(engine: speechRecognizer.SpeechRecognitionEngine): void {
    const rest = this.pending
    if (rest.length === 0) {
      return
    }
    const tail = new Uint8Array(CHUNK_BYTES)
    tail.set(rest, 0)
    try {
      engine.writeAudio(this.sessionId, tail)
    } catch (err) {
    }
    this.pending = new Uint8Array(0)
  }

  private stopCapturer(): void {
    const capturer = this.capturer
    if (capturer === null) {
      return
    }
    this.capturer = null
    try {
      capturer.off('readData')
    } catch (err) {
    }
    capturer.stop().then(() => {
      capturer.release().catch(() => {
      })
    }).catch(() => {
      capturer.release().catch(() => {
      })
    })
  }

  private releaseEngine(): void {
    const engine = this.engine
    this.engine = null
    this.listening = false
    if (engine !== null) {
      try {
        engine.shutdown()
      } catch (err) {
      }
    }
  }

  private clearTimer(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer)
      this.timer = -1
    }
  }
}

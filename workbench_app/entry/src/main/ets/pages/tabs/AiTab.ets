import { Fmt, toast } from '../../common/AppKit'
import { Options } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { SseStream } from '../../common/Http'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { SpeechInput } from '../../common/SpeechInput'
import { actionStateLabel, AI_TOOL_NAMES, runAiAction } from '../../common/AiActions'
import { MdSpan, parseMarkdown } from '../../common/Markdown'
import { AiAction, AiActionField, AiConversationSummary, AiSettingsPayload } from '../../model/Models'
import { Chip, EmptyView, OptionChips, PAGE_PAD_H, PillButton, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader } from '../../components/Ui'

const SCOPE_KEYS: string[] =
  ['schedules', 'habits', 'learning', 'knowledge', 'collections', 'health', 'workouts', 'interviews', 'finance', 'shopping']
const SCOPE_LABELS: string[] = ['日程', '习惯', '学习', '知识库', '收藏', '健康', '健身', '面试', '财务', '待买']

/** 后端回传的待确认操作在 UI 层的可变副本 */
class ChatAction {
  tool: string = ''
  label: string = ''
  args: Record<string, Object> = {}
  fields: AiActionField[] = []
  status: string = 'pending'
  error: string = ''

  constructor(source: AiAction) {
    this.tool = source.tool
    this.label = source.label
    this.args = source.args
    this.fields = source.fields
    this.status = source.status
    this.error = source.error ?? ''
  }
}

class ChatMsg {
  id: string = ''
  role: string = ''
  content: string = ''
  error: string = ''
  pending: boolean = false
  dbId: number = 0
  actions: ChatAction[] = []
  rev: number = 0

  constructor(id: string, role: string, content: string) {
    this.id = id
    this.role = role
    this.content = content
  }
}

function toChatActions(list: AiAction[] | null | undefined): ChatAction[] {
  if (list === null || list === undefined) {
    return []
  }
  const result: ChatAction[] = []
  for (const item of list) {
    result.push(new ChatAction(item))
  }
  return result
}

@Component
export struct AiTab {
  @Consume('topInset') topInset: number
  private scroller: Scroller = new Scroller()
  @State messages: ChatMsg[] = []
  @State input: string = ''
  @State sending: boolean = false
  @State conversationId: number = 0
  @State conversations: AiConversationSummary[] = []
  @State showConv: boolean = false
  @State showSettings: boolean = false
  @State renamingId: number = 0
  @State renameText: string = ''
  @State currentModel: string = ''
  // 设置表单
  @State settingsLoaded: boolean = false
  @State apiKey: string = ''
  @State baseUrl: string = 'https://api.deepseek.com'
  @State modelIndex: number = 0
  @State temperature: number = 0.7
  @State systemPrompt: string = ''
  @State scopeSelected: boolean[] = [true, true, true, true, true, true, true, true, true, true]
  @State hasKey: boolean = false
  @State keyPreview: string = ''
  @State savingSettings: boolean = false
  @State testMessage: string = ''
  @State busyAction: boolean = false
  @State voiceOn: boolean = false
  @State voicePending: boolean = false
  private speech: SpeechInput = new SpeechInput()
  private inputController: TextAreaController = new TextAreaController()
  private stream: SseStream | undefined = undefined
  private flushTimer: number = -1
  private voiceBase: string = ''
  private voiceActive: boolean = false

  aboutToAppear(): void {
    this.loadConversations()
  }

  aboutToDisappear(): void {
    // 切走 tab 时释放麦克风，别让录音一直挂在后台
    this.speech.cancel()
    this.voiceOn = false
    this.voicePending = false
    this.voiceActive = false
    this.stopStreamFlush()
    if (this.stream !== undefined) {
      this.stream.cancel()
      this.stream = undefined
    }
  }

  loadConversations(): void {
    Api.listAiConversations().then((list) => {
      this.conversations = list
    }).catch(() => {
    })
  }

  loadSettings(): void {
    Api.aiSettings().then((settings) => {
      this.baseUrl = settings.baseUrl
      this.modelIndex = settings.model === 'deepseek-reasoner' ? 1 : 0
      this.temperature = settings.temperature
      this.systemPrompt = settings.systemPrompt
      this.hasKey = settings.hasApiKey
      this.keyPreview = settings.apiKeyPreview === null || settings.apiKeyPreview === undefined ? '' : settings.apiKeyPreview
      const selected: boolean[] = []
      for (const key of SCOPE_KEYS) {
        selected.push(settings.contextScope.indexOf(key) >= 0)
      }
      this.scopeSelected = selected
      this.currentModel = settings.model
      this.settingsLoaded = true
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载 AI 设置失败')
    })
  }

  openConversations(): void {
    this.renamingId = 0
    this.showConv = true
  }

  openSettings(): void {
    this.testMessage = ''
    this.showSettings = true
    if (!this.settingsLoaded) {
      this.loadSettings()
    }
  }

  newConversation(): void {
    this.conversationId = 0
    this.messages = []
    this.showConv = false
  }

  openConversation(item: AiConversationSummary): void {
    if (this.sending) {
      toast('请等待当前回复完成')
      return
    }
    Api.getAiConversation(item.id).then((detail) => {
      const list: ChatMsg[] = []
      for (const msg of detail.messages) {
        const m = new ChatMsg(msg.id.toString(), msg.role, msg.content)
        m.dbId = msg.id
        m.actions = toChatActions(msg.actions)
        if (msg.error !== null && msg.error !== undefined && msg.error.length > 0) {
          m.error = msg.error
        }
        list.push(m)
      }
      this.messages = list
      this.conversationId = item.id
      this.showConv = false
      this.scrollToBottom()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载会话失败')
    })
  }

  removeConversation(id: number): void {
    Api.deleteAiConversation(id).then(() => {
      toast('会话已删除')
      if (id === this.conversationId) {
        this.newConversation()
      }
      this.loadConversations()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  saveRename(): void {
    if (this.renameText.trim().length === 0) {
      toast('标题不能为空')
      return
    }
    Api.renameAiConversation(this.renamingId, this.renameText.trim()).then(() => {
      this.renamingId = 0
      this.loadConversations()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '重命名失败')
    })
  }

  scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 120)
  }

  /**
   * 默认模式是整页上移，键盘一弹就把标题栏顶出屏幕；
   * RESIZE 改成压缩页面高度，标题栏不动、消息区变矮，输入区正好贴在键盘上。
   * 只在输入框持有焦点期间生效，避免影响其他页面的输入框。
   */
  useResizeAvoidance(resize: boolean): void {
    this.getUIContext().setKeyboardAvoidMode(resize ? KeyboardAvoidMode.RESIZE : KeyboardAvoidMode.OFFSET)
  }

  send(): void {
    if (this.voiceOn) {
      this.stopVoice()
      return
    }
    if (this.voicePending) {
      return
    }
    const content = this.input.trim()
    if (content.length === 0 || this.sending) {
      return
    }
    this.voiceActive = false
    this.input = ''
    // 发出去就把键盘收起，不然回复会被挡在下面
    this.inputController.stopEditing()
    const userMsg = new ChatMsg('u' + Date.now().toString(), 'user', content)
    const botMsg = new ChatMsg('a' + Date.now().toString(), 'assistant', '')
    botMsg.pending = true
    const withUser = this.messages.concat([userMsg])
    this.messages = withUser.concat([botMsg])
    this.sending = true
    this.scrollToBottom()

    this.stream = Api.aiChatStream(content, this.conversationId, AI_TOOL_NAMES, {
      onMeta: (model: string, conversationId: number): void => {
        if (model.length > 0) {
          this.currentModel = model
        }
        if (conversationId > 0 && conversationId !== this.conversationId) {
          this.conversationId = conversationId
          this.loadConversations()
        }
      },
      onDelta: (text: string): void => {
        botMsg.content += text
        this.scheduleStreamFlush(botMsg)
      },
      onDone: (messageId: number, actions: AiAction[] | null): void => {
        if (messageId > 0) {
          botMsg.dbId = messageId
        }
        botMsg.actions = toChatActions(actions)
      },
      onEnd: (error: string): void => {
        this.stopStreamFlush()
        botMsg.pending = false
        if (error.length > 0) {
          botMsg.error = error
        } else if (botMsg.content.length === 0 && botMsg.actions.length === 0 && botMsg.error.length === 0) {
          botMsg.error = '模型没有返回内容'
        }
        this.stream = undefined
        this.sending = false
        this.messages = this.messages.slice()
        this.loadConversations()
        this.scrollToBottom()
      }
    })
  }

  /**
   * delta 基本一个字一帧，逐帧刷新会让整条气泡连 markdown 一起重排；
   * 按约 10fps 合并成一次，看起来就是打字机，也不会把 UI 线程占满。
   */
  scheduleStreamFlush(msg: ChatMsg): void {
    if (this.flushTimer >= 0) {
      return
    }
    this.flushTimer = setTimeout(() => {
      this.flushTimer = -1
      msg.rev += 1
      this.messages = this.messages.slice()
      this.scrollToBottom()
    }, 90)
  }

  stopStreamFlush(): void {
    if (this.flushTimer >= 0) {
      clearTimeout(this.flushTimer)
      this.flushTimer = -1
    }
  }

  /**
   * 识别结果是整段覆盖式的，所以只保留本次录音开始前的内容，
   * 之后的文字每次用最新结果替换；再说一次会覆盖同一截。
   */
  startVoice(): void {
    if (this.voiceOn || this.voicePending || this.sending) {
      return
    }
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      toast('当前页面无法申请麦克风权限')
      return
    }
    SpeechInput.requestMic(context as common.UIAbilityContext).then((granted: boolean) => {
      if (!granted) {
        toast('需要麦克风权限才能语音输入')
        return
      }
      this.voiceBase = this.input
      this.voiceActive = true
      this.voiceOn = true
      this.inputController.stopEditing()
      this.speech.start((text: string, isFinal: boolean) => {
        if (this.voiceActive) {
          this.input = this.voiceBase + text
        }
      }, (message: string) => {
        this.voiceOn = false
        this.voicePending = false
        this.voiceActive = false
        if (message.length > 0) {
          toast(message)
        }
      }).catch((err: Object) => {
        this.voiceOn = false
        this.voicePending = false
        this.voiceActive = false
        toast(err instanceof Error ? err.message : '语音识别启动失败')
      })
    }).catch(() => {
      toast('语音识别不可用')
    })
  }

  stopVoice(): void {
    if (!this.voiceOn) {
      return
    }
    this.voiceOn = false
    this.voicePending = true
    this.speech.stop()
    // 引擎若没有回调 onComplete，也要把输入框交还给用户
    setTimeout(() => {
      if (this.voicePending) {
        this.voicePending = false
        this.voiceActive = false
      }
    }, 4000)
  }

  bubbleText(msg: ChatMsg): string {
    if (msg.content.length === 0) {
      if (msg.pending) {
        return '正在思考…'
      }
      return msg.actions.length > 0 ? '我整理了这些待确认的操作，点「确认创建」才会写入：' : ''
    }
    const text = Fmt.plainContent(msg.content)
    // 生成中补一个光标位，静止的文字才像在打字
    return msg.pending ? text + '▍' : text
  }

  /** AI 回复按 markdown 排版，用户自己说的话保持原样 */
  mdSpans(msg: ChatMsg): MdSpan[] {
    return parseMarkdown(this.bubbleText(msg), 14)
  }

  actionStateColor(status: string): string {
    if (status === 'done') {
      return Theme.SUCCESS
    }
    if (status === 'failed') {
      return Theme.DANGER
    }
    if (status === 'cancelled') {
      return Theme.TEXT_FAINT
    }
    return Theme.WARN
  }

  reportAction(msg: ChatMsg, index: number, status: string, error: string): void {
    if (msg.dbId <= 0) {
      return
    }
    Api.reportAiAction(msg.dbId, index, status, error).catch(() => {
    })
  }

  /** 卡片上的确认：用 app 自己的创建接口写库，再把结果回传给后端 */
  applyAction(msg: ChatMsg, index: number, approve: boolean): void {
    const action = msg.actions[index]
    if (action === undefined || action.status !== 'pending' || this.busyAction) {
      return
    }
    if (!approve) {
      action.status = 'cancelled'
      this.refreshAction(msg)
      this.reportAction(msg, index, 'cancelled', '')
      return
    }
    this.busyAction = true
    runAiAction(action.tool, action.args).then((tip) => {
      action.status = 'done'
      action.error = ''
      toast(tip)
      Session.bumpDataVersion()
      this.reportAction(msg, index, 'done', '')
    }).catch((err: Object) => {
      action.status = 'failed'
      action.error = err instanceof Error ? err.message : '创建失败'
      toast(action.error)
      this.reportAction(msg, index, 'failed', action.error)
    }).finally(() => {
      this.busyAction = false
      this.refreshAction(msg)
      this.scrollToBottom()
    })
  }

  refreshAction(msg: ChatMsg): void {
    msg.rev += 1
    this.messages = this.messages.slice()
  }

  saveSettings(): void {
    const scope: string[] = []
    for (let i = 0; i < SCOPE_KEYS.length; i++) {
      if (this.scopeSelected[i]) {
        scope.push(SCOPE_KEYS[i])
      }
    }
    const payload: AiSettingsPayload = {
      baseUrl: this.baseUrl.trim(),
      model: Options.AI_MODELS[this.modelIndex],
      temperature: this.temperature,
      systemPrompt: this.systemPrompt,
      contextScope: scope
    }
    if (this.apiKey.trim().length > 0) {
      payload.apiKey = this.apiKey.trim()
    }
    this.savingSettings = true
    Api.updateAiSettings(payload).then(() => {
      toast('AI 设置已保存')
      this.apiKey = ''
      this.loadSettings()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    }).finally(() => {
      this.savingSettings = false
    })
  }

  testConnection(): void {
    this.testMessage = '测试中…'
    const payload: AiSettingsPayload = {
      baseUrl: this.baseUrl.trim(),
      model: Options.AI_MODELS[this.modelIndex]
    }
    if (this.apiKey.trim().length > 0) {
      payload.apiKey = this.apiKey.trim()
    }
    Api.testAi(payload).then((result) => {
      this.testMessage = result.ok
        ? '✅ 连接成功（' + result.latencyMs + 'ms）' + (result.reply === undefined ? '' : '：' + result.reply)
        : '❌ ' + result.message
    }).catch((err: Object) => {
      this.testMessage = '❌ ' + (err instanceof Error ? err.message : '测试失败')
    })
  }

  clearKey(): void {
    Api.clearAiKey().then(() => {
      toast('已清除保存的密钥')
      this.apiKey = ''
      this.loadSettings()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '清除失败')
    })
  }

  @Builder
  msgBubble(msg: ChatMsg) {
    Row() {
      if (msg.role === 'user') {
        Blank()
      }
      Column() {
        if (msg.role === 'user') {
          Text(this.bubbleText(msg))
            .fontSize(14)
            .fontColor('#FFFFFF')
            .lineHeight(21)
        } else {
          // SDK 没有内置 Markdown 组件，只能把语法拆成 Span 交给 Text 排版
          Text() {
            ForEach(this.mdSpans(msg), (span: MdSpan) => {
              Span(span.text)
                .fontSize(span.size)
                .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(span.color.length > 0 ? span.color : Theme.TEXT)
                .fontFamily(span.code ? 'monospace,HarmonyOS Sans' : 'HarmonyOS Sans')
                .textBackgroundStyle({
                  color: span.code ? Theme.softOf(Theme.PRIMARY, '22') : Color.Transparent,
                  radius: 4
                })
            }, (span: MdSpan, index: number) => index.toString() + '-' + span.text)
          }
          .fontSize(14)
          .fontColor(Theme.TEXT)
          .width('100%')
        }
        if (msg.error.length > 0) {
          Text('⚠ ' + msg.error)
            .fontSize(12)
            .fontColor(Theme.DANGER)
            .margin({ top: 6 })
        }
        if (msg.role !== 'user' && msg.actions.length > 0) {
          Column({ space: 8 }) {
            ForEach(msg.actions, (action: ChatAction, index: number) => {
              Column({ space: 5 }) {
                Row({ space: 8 }) {
                  Text(action.label)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT)
                    .layoutWeight(1)
                  Text(actionStateLabel(action.status))
                    .fontSize(11)
                    .fontColor(this.actionStateColor(action.status))
                }
                .width('100%')
                ForEach(action.fields, (field: AiActionField) => {
                  Text(field.label + '：' + field.value)
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                    .width('100%')
                }, (field: AiActionField) => field.label)
                if (action.error.length > 0) {
                  Text('⚠ ' + action.error)
                    .fontSize(11)
                    .fontColor(Theme.DANGER)
                    .width('100%')
                }
                if (action.status === 'pending') {
                  Row({ space: 8 }) {
                    PillButton({
                      label: '取消',
                      filled: false,
                      onTap: (): void => {
                        this.applyAction(msg, index, false)
                      }
                    })
                    PillButton({
                      label: this.busyAction ? '创建中…' : '确认创建',
                      filled: true,
                      onTap: (): void => {
                        this.applyAction(msg, index, true)
                      }
                    })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                  .margin({ top: 3 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(10)
              .borderRadius(12)
              .backgroundColor(Theme.INPUT_BG)
              .border({ width: 1, color: Theme.BORDER })
            }, (action: ChatAction, index: number) => index.toString() + '-' + action.status + '-' + action.error)
          }
          .width('100%')
          .margin({ top: 10 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      // 光靠 maxWidth 卡片只会包到文字宽度，AI 回复要铺满得把最小宽度也顶到 100%
      .constraintSize({
        maxWidth: msg.role === 'user' ? '78%' : '100%',
        minWidth: msg.role === 'user' ? 0 : '100%'
      })
      .padding(12)
      .borderRadius(16)
      .linearGradient({
        angle: 135,
        colors: msg.role === 'user' ? Theme.BRAND_COLORS : Theme.CARD_COLORS
      })
      .border({ width: 1, color: msg.role === 'user' ? '#3B82F6' : Theme.BORDER })
      if (msg.role !== 'user') {
        Blank()
      }
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  build() {
    Stack() {
      Column() {
        // 顶部栏
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('AI 助手')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
            Text(this.conversationId > 0 ? '会话 #' + this.conversationId + (this.currentModel.length > 0 ? ' · ' + this.currentModel : '') : '基于 DeepSeek · 可读取平台数据')
              .fontSize(10)
              .fontColor(Theme.TEXT_FAINT)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('＋ 新对话')
            .fontSize(12)
            .fontColor(Theme.MINT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(10)
            .border({ width: 1, color: Theme.MINT })
            .onClick(() => {
              this.newConversation()
            })
          Text('💬')
            .fontSize(18)
            .onClick(() => {
              this.openConversations()
            })
          Text('⚙️')
            .fontSize(18)
            .onClick(() => {
              this.openSettings()
            })
        }
        .width('100%')
        .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, top: this.topInset + 12, bottom: 8 })

        // 消息区
        Column() {
          if (this.messages.length === 0) {
            Column({ space: 10 }) {
              EmptyView({ icon: '🤖', text: '向 AI 提问关于你的一切：\n日程、习惯、财务、学习、体重…' })
              Text('试试：“总结一下我这周的学习进度”')
                .fontSize(11)
                .fontColor(Theme.CYAN)
              Text('也可以直接说：“明天下午三点提醒我看牙医”')
                .fontSize(11)
                .fontColor(Theme.MINT)
            }
          } else {
            List({ scroller: this.scroller, space: 0 }) {
              ForEach(this.messages, (msg: ChatMsg) => {
                ListItem() {
                  this.msgBubble(msg)
                }
              }, (msg: ChatMsg) => msg.id + '-' + msg.pending.toString() + '-' + msg.rev.toString())
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            // 键盘压缩消息区后滚动位置不会自己跟到底，补一次，最后一条才不会被键盘吃掉
            .onAreaChange(() => {
              this.scrollToBottom()
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H })

        // 输入区
        if (this.voiceOn || this.voicePending) {
          Text(this.voiceOn ? '正在录音，说完点右侧方块结束' : '正在识别刚才说的话…')
            .fontSize(11)
            .fontColor(this.voiceOn ? Theme.DANGER : Theme.TEXT_SUB)
            .width('100%')
            .padding({ left: PAGE_PAD_H, bottom: 4 })
        }
        Row({ space: 10 }) {
          // 单行时靠对称内边距居中，输入多行时自然长高到 4 行为止（固定 height 会让 placeholder 顶在上面）
          TextArea({ placeholder: '输入你的问题…', text: this.input, controller: this.inputController })
            .placeholderColor(Theme.TEXT_FAINT)
            .fontColor(Theme.TEXT)
            .fontSize(14)
            .backgroundColor(Theme.INPUT_BG)
            .borderRadius(14)
            .border({ width: 1, color: Theme.BORDER })
            .constraintSize({ minHeight: 44 })
            .padding({ left: 14, right: 14, top: 11, bottom: 11 })
            .align(Alignment.Start)
            .maxLines(4)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.input = value
            })
            .onFocus(() => {
              this.useResizeAvoidance(true)
            })
            .onBlur(() => {
              this.useResizeAvoidance(false)
            })
          Text(this.voiceOn ? '⏹' : (this.voicePending ? '⏳' : '🎤'))
            .fontSize(16)
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .borderRadius(14)
            .backgroundColor(Theme.INPUT_BG)
            .border({ width: 1, color: this.voiceOn ? Theme.DANGER : Theme.BORDER })
            .opacity(this.sending ? 0.5 : 1)
            .onClick(() => {
              if (this.voiceOn) {
                this.stopVoice()
              } else {
                this.startVoice()
              }
            })
          Text(this.voiceOn ? '停止' : (this.sending ? '…' : '发送'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width(58)
            .height(44)
            .textAlign(TextAlign.Center)
            .borderRadius(14)
            .linearGradient({ angle: 135, colors: this.sending ? Theme.CARD_COLORS : Theme.BRAND_COLORS })
            .opacity(this.sending ? 0.6 : 1)
            .onClick(() => {
              this.send()
            })
        }
        .width('100%')
        .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: 10, top: 6 })
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .height('100%')

      .bindSheet($$this.showConv, this.convSheetBuilder(), {
        height: 620,
        dragBar: true,
        backgroundColor: Theme.CARD_SOLID
      })
    }
    .width('100%')
    .height('100%')
    // 点消息区等空白处也收起键盘：click 会冒泡到这里，输入框失焦后避让模式自动还原
    .onClick(() => {
      this.inputController.stopEditing()
    })
    .bindSheet($$this.showSettings, this.settingsBuilder(), {
      height: 700,
      dragBar: true,
      backgroundColor: Theme.CARD_SOLID
    })
  }

  @Builder
  convSheetBuilder() {
    Column() {
      Column() {
        SheetHeader({
          title: '会话列表',
          actionLabel: '＋ 新建',
          onAction: (): void => {
            this.newConversation()
          }
        })
      }
      .width('100%')
      .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, top: SHEET_PAD_TOP, bottom: 6 })

      if (this.renamingId > 0) {
        Row({ space: 8 }) {
          TextInput({ text: this.renameText })
            .fontColor(Theme.TEXT)
            .fontSize(13)
            .backgroundColor(Theme.INPUT_BG)
            .borderRadius(10)
            .border({ width: 1, color: Theme.BORDER })
            .height(40)
            .align(Alignment.Start)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.renameText = value
            })
          PillButton({
            label: '取消',
            filled: false,
            onTap: (): void => {
              this.renamingId = 0
            }
          })
          PillButton({
            label: '保存',
            filled: true,
            onTap: (): void => {
              this.saveRename()
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, top: 6 })
      }

      if (this.conversations.length === 0) {
        EmptyView({ icon: '💬', text: '还没有会话，发第一条消息开始对话' })
      } else {
        List() {
          ForEach(this.conversations, (item: AiConversationSummary) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(item.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.conversationId === item.id ? Theme.CYAN : Theme.TEXT)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(item.messageCount + ' 条')
                    .fontSize(10)
                    .fontColor(Theme.TEXT_FAINT)
                }
                .width('100%')
                Text(item.preview.length > 0 ? item.preview : '（空会话）')
                  .fontSize(11)
                  .fontColor(Theme.TEXT_SUB)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Row({ space: 10 }) {
                  Text(item.lastMessageAt === null || item.lastMessageAt === undefined
                    ? item.createdAt : item.lastMessageAt)
                    .fontSize(10)
                    .fontColor(Theme.TEXT_FAINT)
                    .layoutWeight(1)
                  Text('重命名')
                    .fontSize(11)
                    .fontColor(Theme.CYAN)
                    .onClick(() => {
                      this.renamingId = item.id
                      this.renameText = item.title
                    })
                  Text('删除')
                    .fontSize(11)
                    .fontColor(Theme.DANGER)
                    .onClick(() => {
                      this.removeConversation(item.id)
                    })
                }
                .width('100%')
              }
              .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: Theme.BORDER })
              .onClick(() => {
                this.openConversation(item)
              })
            }
          }, (item: AiConversationSummary) => item.id.toString() + '-' + item.updatedAt)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .height('100%')
  }

  @Builder
  settingsBuilder() {
    Scroll() {
      Column() {
        SheetHeader({ title: '模型配置' })

        Text('API Key').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        // 输入框高度大于行高时，placeholder 与文本的竖向位置由 align 决定（textAlign 只管横向）
        TextInput({ placeholder: this.hasKey ? '已保存：' + this.keyPreview + '（留空则不修改）' : 'sk-…', text: this.apiKey })
          .placeholderColor(Theme.TEXT_FAINT)
          .fontColor(Theme.TEXT)
          .fontSize(13)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(42)
          .align(Alignment.Start)
          .type(InputType.Password)
          .onChange((value: string) => {
            this.apiKey = value
          })

        Text('接口地址').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        TextInput({ text: this.baseUrl })
          .fontColor(Theme.TEXT)
          .fontSize(13)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.baseUrl = value
          })

        Text('模型').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        OptionChips({
          options: Options.AI_MODELS,
          selected: this.modelIndex,
          onSelect: (index: number) => {
            this.modelIndex = index
          }
        })

        Text('Temperature：' + this.temperature.toFixed(1))
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 14, bottom: 6 })
        Slider({ value: this.temperature, min: 0, max: 2, step: 0.1 })
          .selectedColor(Theme.PRIMARY)
          .trackColor(Theme.BORDER)
          .onChange((value: number) => {
            this.temperature = Math.round(value * 10) / 10
          })

        Text('系统提示词').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
        TextArea({ text: this.systemPrompt })
          .fontColor(Theme.TEXT)
          .fontSize(13)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(90)
          .onChange((value: string) => {
            this.systemPrompt = value
          })

        Text('数据上下文（AI 可读取的数据范围）')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .margin({ top: 14, bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(SCOPE_KEYS, (key: string, index: number) => {
            Chip({
              text: SCOPE_LABELS[index],
              color: Theme.MINT,
              selected: this.scopeSelected.length > index && this.scopeSelected[index],
              small: true
            })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                const next: boolean[] = this.scopeSelected.slice()
                next[index] = !next[index]
                this.scopeSelected = next
              })
          }, (key: string) => key + this.scopeSelected.length.toString())
        }
        .width('100%')

        Row({ space: 10 }) {
          Text('测试连接')
            .fontSize(13)
            .fontColor(Theme.CYAN)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(42)
            .borderRadius(12)
            .border({ width: 1, color: Theme.CYAN })
            .onClick(() => {
              this.testConnection()
            })
          Text('清除密钥')
            .fontSize(13)
            .fontColor(Theme.WARN)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(42)
            .borderRadius(12)
            .border({ width: 1, color: Theme.WARN })
            .onClick(() => {
              this.clearKey()
            })
          Text(this.savingSettings ? '保存中…' : '保存')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(42)
            .borderRadius(12)
            .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
            .onClick(() => {
              if (!this.savingSettings) {
                this.saveSettings()
              }
            })
        }
        .width('100%')
        .margin({ top: 18, bottom: 8 })

        if (this.testMessage.length > 0) {
          Text(this.testMessage)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
            .margin({ bottom: 10 })
        }
      }
      .padding({
        left: PAGE_PAD_H,
        right: PAGE_PAD_H,
        top: SHEET_PAD_TOP,
        bottom: SHEET_PAD_BOTTOM
      })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .height('100%')
  }
}

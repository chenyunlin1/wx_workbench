import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { In, Repository } from 'typeorm'
import { AiConversation } from './ai-conversation.entity'
import { AiMessage, AiMessageRole } from './ai-message.entity'
import type { AiAction, AiActionStatus } from './ai-tools'

export interface AiConversationSummary {
  id: number
  title: string
  model: string | null
  messageCount: number
  preview: string
  lastMessageAt: Date | null
  createdAt: Date
  updatedAt: Date
}

const TITLE_MAX = 24

@Injectable()
export class AiConversationService {
  constructor(
    @InjectRepository(AiConversation)
    private readonly conversationRepository: Repository<AiConversation>,
    @InjectRepository(AiMessage)
    private readonly messageRepository: Repository<AiMessage>,
  ) {}

  /** 会话列表：带消息数、最后一条消息摘要，按最近活跃排序 */
  async list(userId: number): Promise<AiConversationSummary[]> {
    const conversations = await this.conversationRepository.find({
      where: { userId },
      order: { lastMessageAt: 'DESC', id: 'DESC' },
      take: 100,
    })
    if (!conversations.length) return []

    const ids = conversations.map((item) => item.id)
    const stats = await this.messageRepository
      .createQueryBuilder('message')
      .select('message.conversationId', 'conversationId')
      .addSelect('COUNT(*)', 'count')
      .addSelect('MAX(message.id)', 'lastId')
      .where('message.conversationId IN (:...ids)', { ids })
      .groupBy('message.conversationId')
      .getRawMany<{ conversationId: number; count: string; lastId: number }>()

    const statMap = new Map(stats.map((row) => [Number(row.conversationId), row]))
    const lastIds = stats.map((row) => Number(row.lastId)).filter(Boolean)
    const lastMessages = lastIds.length
      ? await this.messageRepository.find({ where: { id: In(lastIds) } })
      : []
    const lastMap = new Map(lastMessages.map((message) => [message.conversationId, message]))

    return conversations.map((conversation) => {
      const stat = statMap.get(conversation.id)
      const last = lastMap.get(conversation.id)
      return {
        id: conversation.id,
        title: conversation.title,
        model: conversation.model,
        messageCount: stat ? Number(stat.count) : 0,
        preview: last ? last.content.replace(/\s+/g, ' ').slice(0, 60) : '',
        lastMessageAt: conversation.lastMessageAt ?? conversation.createdAt,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
      }
    })
  }

  async getOrFail(userId: number, id: number) {
    const conversation = await this.conversationRepository.findOne({ where: { id, userId } })
    if (!conversation) throw new NotFoundException('会话不存在')
    return conversation
  }

  /** 会话详情：返回会话与最近若干条消息（按时间正序） */
  async detail(userId: number, id: number, limit = 100) {
    const conversation = await this.getOrFail(userId, id)
    const messages = await this.messageRepository.find({
      where: { conversationId: id, userId },
      order: { id: 'DESC' },
      take: limit,
    })

    return {
      conversation: {
        id: conversation.id,
        title: conversation.title,
        model: conversation.model,
        lastMessageAt: conversation.lastMessageAt,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
      },
      messages: messages.reverse(),
    }
  }

  /** 新建会话；标题缺省时用首条消息生成 */
  async create(userId: number, title?: string) {
    const conversation = this.conversationRepository.create({
      userId,
      title: title?.trim() || '新对话',
      titleEdited: Boolean(title?.trim()),
      model: null,
      lastMessageAt: null,
    })
    return this.conversationRepository.save(conversation)
  }

  async rename(userId: number, id: number, title: string) {
    const conversation = await this.getOrFail(userId, id)
    conversation.title = title.trim()
    conversation.titleEdited = true
    return this.conversationRepository.save(conversation)
  }

  async remove(userId: number, id: number) {
    const conversation = await this.getOrFail(userId, id)
    await this.conversationRepository.remove(conversation)
    return { success: true }
  }

  /** 追加一条消息，并刷新会话的活跃时间与模型 */
  async appendMessage(input: {
    conversation: AiConversation
    role: AiMessageRole
    content: string
    reasoning?: string | null
    model?: string | null
    elapsedMs?: number | null
    contextMeta?: unknown
    error?: string | null
    actions?: AiAction[] | null
  }) {
    const message = await this.messageRepository.save(
      this.messageRepository.create({
        conversationId: input.conversation.id,
        userId: input.conversation.userId,
        role: input.role,
        content: input.content,
        reasoning: input.reasoning ?? null,
        model: input.model ?? null,
        elapsedMs: input.elapsedMs ?? null,
        contextMeta: input.contextMeta ?? null,
        error: input.error ?? null,
        actions: input.actions?.length ? input.actions : null,
      }),
    )

    // 首条用户消息用于自动命名，用户改过标题则不覆盖
    if (
      input.role === AiMessageRole.USER &&
      !input.conversation.titleEdited &&
      input.conversation.title === '新对话'
    ) {
      const text = input.content.replace(/\s+/g, ' ').trim()
      input.conversation.title = text.length > TITLE_MAX ? `${text.slice(0, TITLE_MAX)}…` : text || '新对话'
    }

    input.conversation.lastMessageAt = new Date()
    if (input.model) input.conversation.model = input.model
    await this.conversationRepository.save(input.conversation)

    return message
  }

  /**
   * 客户端执行完工具调用后回写结果。动作是否真的落库只有客户端知道，
   * 状态存在这里，重开会话时才不会把已创建的条目再次显示成「待确认」。
   */
  async updateAction(
    userId: number,
    messageId: number,
    index: number,
    status: AiActionStatus,
    error?: string,
  ) {
    const message = await this.messageRepository.findOne({ where: { id: messageId, userId } })
    if (!message) throw new NotFoundException('消息不存在')

    const actions = message.actions
    if (!actions || !actions.length) throw new NotFoundException('该消息没有待执行的操作')

    const action = actions[index]
    if (!action) throw new NotFoundException('操作不存在')

    action.status = status
    action.error = error?.trim().slice(0, 200) ?? null
    await this.messageRepository.save(message)
    return { messageId, actions }
  }

  /** 取会话历史，转成模型需要的消息数组 */
  async history(conversationId: number, limit: number) {
    const messages = await this.messageRepository.find({
      where: { conversationId },
      order: { id: 'DESC' },
      take: limit,
    })

    return messages
      .reverse()
      .filter((message) => !message.error && (message.content.trim().length > 0 || message.actions?.length))
      .map((message) => ({
        role: message.role === AiMessageRole.USER ? ('user' as const) : ('assistant' as const),
        // 只调用了工具、正文为空的回复要转述给模型，否则下一轮它会以为什么都没做过
        content: message.content.trim() || this.describeActions(message.actions),
      }))
  }

  private describeActions(actions?: AiAction[] | null) {
    if (!actions?.length) return ''
    const items = actions.map(
      (action) =>
        `${action.label}（${action.fields.map((field) => `${field.label} ${field.value}`).join('，')}）：${
          action.status === 'done' ? '用户已确认创建' : action.status === 'cancelled' ? '用户已取消' : '等待用户确认'
        }`,
    )
    return `（上一轮我提交了这些待确认操作：${items.join('；')}。请据此回答，不要重复提交同样的内容。）`
  }
}

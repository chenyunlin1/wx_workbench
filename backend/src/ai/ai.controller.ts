import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put, Query, Req, Res } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import type { Request, Response } from 'express'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { RawResponse } from '../common/decorators/raw-response.decorator'
import type { User } from '../entities'
import { AiConversationService } from './ai-conversation.service'
import { AiService } from './ai.service'
import { ChatDto } from './dto/chat.dto'
import { CreateConversationDto, UpdateConversationDto } from './dto/conversation.dto'
import { QueryAiContextDto } from './dto/query-ai-context.dto'
import { ReportAiActionDto } from './dto/report-ai-action.dto'
import { TestConnectionDto } from './dto/test-connection.dto'
import { UpdateAiSettingsDto } from './dto/update-ai-settings.dto'

@ApiTags('AI 助手')
@ApiBearerAuth()
@Controller('ai')
export class AiController {
  constructor(
    private readonly aiService: AiService,
    private readonly conversationService: AiConversationService,
  ) {}

  @Get('conversations')
  @ApiOperation({ summary: '会话列表（含消息数与最后一条摘要）' })
  listConversations(@CurrentUser('id') userId: number) {
    return this.conversationService.list(userId)
  }

  @Post('conversations')
  @ApiOperation({ summary: '新建会话' })
  createConversation(@CurrentUser('id') userId: number, @Body() dto: CreateConversationDto) {
    return this.conversationService.create(userId, dto.title)
  }

  @Get('conversations/:id')
  @ApiOperation({ summary: '会话详情与消息记录' })
  getConversation(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.conversationService.detail(userId, id)
  }

  @Patch('conversations/:id')
  @ApiOperation({ summary: '重命名会话' })
  renameConversation(
    @CurrentUser('id') userId: number,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateConversationDto,
  ) {
    return this.conversationService.rename(userId, id, dto.title)
  }

  @Delete('conversations/:id')
  @ApiOperation({ summary: '删除会话及其消息' })
  removeConversation(@CurrentUser('id') userId: number, @Param('id', ParseIntPipe) id: number) {
    return this.conversationService.remove(userId, id)
  }

  @Get('settings')
  @ApiOperation({ summary: '获取 AI 助手配置（密钥脱敏）' })
  getSettings(@CurrentUser('id') userId: number) {
    return this.aiService.getSettings(userId)
  }

  @Put('settings')
  @ApiOperation({ summary: '保存 AI 助手配置' })
  updateSettings(@CurrentUser('id') userId: number, @Body() dto: UpdateAiSettingsDto) {
    return this.aiService.updateSettings(userId, dto)
  }

  @Delete('settings/key')
  @ApiOperation({ summary: '清除已保存的 API Key' })
  clearApiKey(@CurrentUser('id') userId: number) {
    return this.aiService.clearApiKey(userId)
  }

  @Post('settings/test')
  @ApiOperation({ summary: '测试 API Key 与模型连通性' })
  testConnection(@CurrentUser() user: User, @Body() dto: TestConnectionDto) {
    return this.aiService.testConnection(user, dto)
  }

  @Get('context')
  @ApiOperation({ summary: '预览将要提供给模型的个人数据快照' })
  getContext(@CurrentUser() user: User, @Query() query: QueryAiContextDto) {
    return this.aiService.getContext(user, query.resolveScope())
  }

  @Post('chat')
  @ApiOperation({ summary: 'AI 对话（一次性返回）' })
  chat(@CurrentUser() user: User, @Body() dto: ChatDto) {
    return this.aiService.chat(user, dto)
  }

  @Post('chat/stream')
  @RawResponse()
  @ApiOperation({ summary: 'AI 对话（SSE 流式返回）' })
  streamChat(
    @CurrentUser() user: User,
    @Body() dto: ChatDto,
    @Req() request: Request,
    @Res() response: Response,
  ) {
    return this.aiService.streamChat(user, dto, request, response)
  }

  @Patch('messages/:messageId/actions')
  @ApiOperation({ summary: '回写工具调用的执行结果（客户端真正创建了记录后调用）' })
  reportAction(
    @CurrentUser('id') userId: number,
    @Param('messageId', ParseIntPipe) messageId: number,
    @Body() dto: ReportAiActionDto,
  ) {
    return this.conversationService.updateAction(userId, messageId, dto.index, dto.status, dto.error)
  }
}

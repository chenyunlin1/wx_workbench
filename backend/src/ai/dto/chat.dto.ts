import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator'
import { AI_CONTEXT_SCOPES, AI_MESSAGE_MAX_LENGTH, type AiContextScope } from '../ai.constants'

export const AI_CHAT_ROLES = ['user', 'assistant'] as const
export type AiChatRole = (typeof AI_CHAT_ROLES)[number]

export class AiChatMessageDto {
  @ApiProperty({ enum: AI_CHAT_ROLES, example: 'user' })
  @IsIn(AI_CHAT_ROLES)
  role: AiChatRole

  @ApiProperty({ example: '帮我总结今天的安排' })
  @IsString()
  @MinLength(1)
  @MaxLength(AI_MESSAGE_MAX_LENGTH)
  content: string
}

export class ChatDto {
  @ApiPropertyOptional({ example: 1, description: '会话 ID；不传且带 content 时会自动新建会话' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  conversationId?: number

  @ApiPropertyOptional({
    type: [AiChatMessageDto],
    description: '无会话时的完整对话历史，最后一条为用户当前提问',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => AiChatMessageDto)
  messages?: AiChatMessageDto[]

  @ApiPropertyOptional({ description: '单轮提问的快捷写法，与 messages 二选一' })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(AI_MESSAGE_MAX_LENGTH)
  content?: string

  @ApiPropertyOptional({
    type: [String],
    description: '客户端可实现的工具名；不传表示下发全部工具，传了则只下发这份名单',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @IsString({ each: true })
  toolNames?: string[]

  @ApiPropertyOptional({
    enum: AI_CONTEXT_SCOPES,
    isArray: true,
    description: '本次对话允许读取的平台数据范围，缺省使用用户配置',
  })
  @IsOptional()
  @IsArray()
  @IsIn(AI_CONTEXT_SCOPES, { each: true })
  contextScope?: AiContextScope[]

  @ApiPropertyOptional({ description: '是否附带个人数据快照，默认 true' })
  @IsOptional()
  @IsBoolean()
  useContext?: boolean

  @ApiPropertyOptional({
    description: '是否启用服务端执行的高驰 MCP 工具，默认已连接就启用；传 false 可临时关掉',
  })
  @IsOptional()
  @IsBoolean()
  useMcp?: boolean

  @ApiPropertyOptional({ example: 0.7, minimum: 0, maximum: 2 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(2)
  temperature?: number
}

import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import {
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator'
import {
  AI_CONTEXT_SCOPES,
  AI_SYSTEM_PROMPT_MAX_LENGTH,
  type AiContextScope,
} from '../ai.constants'

export class UpdateAiSettingsDto {
  @ApiPropertyOptional({ example: 'deepseek' })
  @IsOptional()
  @IsString()
  @MaxLength(32)
  provider?: string

  @ApiPropertyOptional({
    example: 'sk-xxxxxxxx',
    description: '留空字符串表示清除已保存的密钥；返回的脱敏值会被忽略',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiKey?: string

  @ApiPropertyOptional({ example: 'https://api.deepseek.com' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  baseUrl?: string

  @ApiPropertyOptional({ example: 'deepseek-chat' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  model?: string

  @ApiPropertyOptional({ example: 0.7, minimum: 0, maximum: 2 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(2)
  temperature?: number

  @ApiPropertyOptional({ description: '自定义系统提示词，留空使用内置提示词' })
  @IsOptional()
  @IsString()
  @MaxLength(AI_SYSTEM_PROMPT_MAX_LENGTH)
  systemPrompt?: string

  @ApiPropertyOptional({ enum: AI_CONTEXT_SCOPES, isArray: true })
  @IsOptional()
  @IsArray()
  @IsIn(AI_CONTEXT_SCOPES, { each: true })
  contextScope?: AiContextScope[]
}

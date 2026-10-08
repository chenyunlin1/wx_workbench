import { ApiPropertyOptional } from '@nestjs/swagger'
import { IsOptional, IsString } from 'class-validator'
import { AI_CONTEXT_SCOPES, DEFAULT_AI_CONTEXT_SCOPES, type AiContextScope } from '../ai.constants'

export class QueryAiContextDto {
  @ApiPropertyOptional({
    description: '逗号分隔的数据范围，缺省返回全部范围',
    example: 'schedules,finance',
  })
  @IsOptional()
  @IsString()
  scope?: string

  /** 解析 scope 参数，非法项直接忽略。 */
  resolveScope(): AiContextScope[] {
    if (!this.scope) return [...DEFAULT_AI_CONTEXT_SCOPES]
    const parsed = this.scope
      .split(',')
      .map((item) => item.trim())
      .filter((item): item is AiContextScope =>
        (AI_CONTEXT_SCOPES as readonly string[]).includes(item),
      )
    return parsed.length ? parsed : [...DEFAULT_AI_CONTEXT_SCOPES]
  }
}

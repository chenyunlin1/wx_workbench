import { ApiPropertyOptional } from '@nestjs/swagger'
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator'

export class CreateConversationDto {
  @ApiPropertyOptional({ example: '本周训练计划', description: '缺省用首条消息自动命名' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string
}

export class UpdateConversationDto {
  @ApiPropertyOptional({ example: '关于体重的讨论' })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  title: string
}

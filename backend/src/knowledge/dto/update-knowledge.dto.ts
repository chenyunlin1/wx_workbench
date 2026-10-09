import { ApiPropertyOptional } from '@nestjs/swagger'
import { Transform } from 'class-transformer'
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator'
import { KnowledgeType } from '../knowledge.entity'

export class UpdateKnowledgeDto {
  @ApiPropertyOptional({ enum: KnowledgeType, example: KnowledgeType.NOTE })
  @IsOptional()
  @IsEnum(KnowledgeType, { message: '类型只能是 note 或 qa' })
  type?: KnowledgeType

  @ApiPropertyOptional({ example: '更新后的标题' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  title?: string

  @ApiPropertyOptional({ example: '更新后的知识内容' })
  @IsOptional()
  @IsString()
  content?: string

  @ApiPropertyOptional({ type: [String], example: ['Vue3', 'Pinia'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @Transform(({ value }) =>
    Array.isArray(value)
      ? [...new Set(value.map((tag: string) => String(tag).trim()).filter(Boolean))]
      : [],
  )
  tags?: string[]

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isLearned?: boolean

  @ApiPropertyOptional({ example: false, description: '是否为公共知识（所有账号可见）' })
  @IsOptional()
  @IsBoolean()
  isPublic?: boolean
}
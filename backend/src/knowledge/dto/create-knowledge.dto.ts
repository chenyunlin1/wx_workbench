import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Transform } from 'class-transformer'
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator'
import { KnowledgeType } from '../knowledge.entity'

export class CreateKnowledgeDto {
  @ApiProperty({ enum: KnowledgeType, example: KnowledgeType.NOTE })
  @IsEnum(KnowledgeType, { message: '类型只能是 note 或 qa' })
  type: KnowledgeType

  @ApiProperty({ example: 'Vue3 响应式原理 | ref 与 reactive 的区别' })
  @IsString()
  @IsNotEmpty({ message: '标题不能为空' })
  @MaxLength(255)
  title: string

  @ApiProperty({ example: 'ref 用于定义基本类型，reactive 用于定义对象类型。' })
  @IsString()
  @IsNotEmpty({ message: '内容不能为空' })
  content: string

  @ApiPropertyOptional({ type: [String], example: ['Vue3', 'TypeScript'] })
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

  @ApiPropertyOptional({ example: false, description: '是否为公共知识（所有账号可见）' })
  @IsOptional()
  @IsBoolean()
  isPublic?: boolean
}
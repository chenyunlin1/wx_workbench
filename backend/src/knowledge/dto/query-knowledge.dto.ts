import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsEnum, IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator'
import { KnowledgeType } from '../knowledge.entity'

export const KNOWLEDGE_SORT_FIELDS = ['updatedAt', 'createdAt', 'views'] as const
export type KnowledgeSortField = (typeof KNOWLEDGE_SORT_FIELDS)[number]

export class QueryKnowledgeDto {
  @ApiPropertyOptional({ example: '响应式' })
  @IsOptional()
  @IsString()
  keyword?: string

  @ApiPropertyOptional({ enum: KnowledgeType })
  @IsOptional()
  @IsEnum(KnowledgeType)
  type?: KnowledgeType

  @ApiPropertyOptional({ example: 'Vue3' })
  @IsOptional()
  @IsString()
  tag?: string

  @ApiPropertyOptional({ example: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1

  @ApiPropertyOptional({ example: 20, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 20

  @ApiPropertyOptional({ enum: KNOWLEDGE_SORT_FIELDS, default: 'updatedAt' })
  @IsOptional()
  @IsIn(KNOWLEDGE_SORT_FIELDS)
  sortBy: KnowledgeSortField = 'updatedAt'
}
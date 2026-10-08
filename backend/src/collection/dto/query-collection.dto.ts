import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsEnum, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator'
import { CollectionStatus, CollectionType } from '../collection.entity'

export const COLLECTION_SORT_FIELDS = ['createdAt', 'rating', 'year', 'title'] as const
export type CollectionSortField = (typeof COLLECTION_SORT_FIELDS)[number]

export class QueryCollectionDto {
  @ApiPropertyOptional({ enum: CollectionType })
  @IsOptional()
  @IsEnum(CollectionType)
  type?: CollectionType

  @ApiPropertyOptional({ enum: CollectionStatus })
  @IsOptional()
  @IsEnum(CollectionStatus)
  status?: CollectionStatus

  @ApiPropertyOptional({ example: '财政' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  keyword?: string

  @ApiPropertyOptional({ example: 2021 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(2100)
  year?: number

  @ApiPropertyOptional({ example: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1

  @ApiPropertyOptional({ example: 24, default: 24 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 24

  @ApiPropertyOptional({ enum: COLLECTION_SORT_FIELDS, default: 'createdAt' })
  @IsOptional()
  @IsIn(COLLECTION_SORT_FIELDS)
  sortBy: CollectionSortField = 'createdAt'
}

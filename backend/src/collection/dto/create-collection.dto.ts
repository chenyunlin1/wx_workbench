import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator'
import { CollectionStatus, CollectionType } from '../collection.entity'

export class CreateCollectionDto {
  @ApiProperty({ enum: CollectionType, example: CollectionType.BOOK })
  @IsEnum(CollectionType)
  type: CollectionType

  @ApiProperty({ example: '置身事内' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(180)
  title: string

  @ApiPropertyOptional({ enum: CollectionStatus, default: CollectionStatus.WISH })
  @IsOptional()
  @IsEnum(CollectionStatus)
  status?: CollectionStatus

  @ApiPropertyOptional({ example: 5, minimum: 1, maximum: 5, nullable: true })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number | null

  @ApiPropertyOptional({ example: 2021, minimum: 0, maximum: 2100, nullable: true })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(2100)
  year?: number | null

  @ApiPropertyOptional({ example: 'https://example.com/cover.jpg', nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string | null

  @ApiPropertyOptional({ example: '把财政讲得通俗易懂，值得二刷。', nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  comment?: string | null
}

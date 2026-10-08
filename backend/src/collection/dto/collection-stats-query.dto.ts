import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsInt, IsOptional, Max, Min } from 'class-validator'

export class CollectionStatsQueryDto {
  @ApiPropertyOptional({ example: 2026, description: '统计年份，缺省为当前年份' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1970)
  @Max(2100)
  year?: number
}

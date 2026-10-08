import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsDateString, IsOptional } from 'class-validator'

export class HabitRecordsQueryDto {
  @ApiPropertyOptional({ example: '2026-09-19', description: '起始日期（含），缺省为 13 天前' })
  @IsOptional()
  @IsDateString()
  start?: string

  @ApiPropertyOptional({ example: '2026-09-25', description: '结束日期（含），缺省为今天' })
  @IsOptional()
  @IsDateString()
  end?: string
}

export class HabitStatsQueryDto {
  @ApiPropertyOptional({ example: 14, default: 14, description: '统计天数（含今天）' })
  @IsOptional()
  @Type(() => Number)
  days?: number
}

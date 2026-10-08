import { ApiPropertyOptional } from '@nestjs/swagger'
import { IsOptional, Matches } from 'class-validator'

export class FinanceStatsQueryDto {
  @ApiPropertyOptional({ example: '2026-09' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}$/, { message: 'month 格式应为 YYYY-MM' })
  month?: string
}
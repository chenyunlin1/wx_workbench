import { ApiPropertyOptional } from '@nestjs/swagger'
import { IsDateString, IsOptional } from 'class-validator'

export class ScheduleQueryDto {
  @ApiPropertyOptional({ example: '2026-09-01T00:00:00+08:00' })
  @IsOptional()
  @IsDateString()
  start?: string

  @ApiPropertyOptional({ example: '2026-10-01T00:00:00+08:00' })
  @IsOptional()
  @IsDateString()
  end?: string
}

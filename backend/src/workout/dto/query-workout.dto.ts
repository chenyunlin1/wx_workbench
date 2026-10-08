import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsDateString, IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator'
import { WorkoutType } from '../workout.entity'

export class QueryWorkoutDto {
  @ApiPropertyOptional({ enum: WorkoutType })
  @IsOptional()
  @IsEnum(WorkoutType)
  type?: WorkoutType

  @ApiPropertyOptional({ example: '2026-09-01', description: '起始时间（含）' })
  @IsOptional()
  @IsDateString()
  from?: string

  @ApiPropertyOptional({ example: '2026-09-30', description: '结束时间（含）' })
  @IsOptional()
  @IsDateString()
  to?: string

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
}

export class WorkoutStatsQueryDto {
  @ApiPropertyOptional({ example: 7, default: 7, description: '统计天数（含今天）' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(90)
  days = 7
}

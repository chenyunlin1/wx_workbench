import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator'
import { SchedulePriority } from '../../entities'

export class CreateScheduleDto {
  @ApiProperty({ example: '项目周会' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  title: string

  @ApiPropertyOptional({ example: '同步本周项目进展' })
  @IsOptional()
  @IsString()
  description?: string

  @ApiProperty({ example: '2026-09-11T09:30:00+08:00' })
  @IsDateString()
  startTime: string

  @ApiPropertyOptional({ example: '2026-09-11T10:30:00+08:00' })
  @IsOptional()
  @IsDateString()
  endTime?: string

  @ApiPropertyOptional({ example: '会议', default: '日程' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string

  @ApiPropertyOptional({ enum: SchedulePriority, default: SchedulePriority.MEDIUM })
  @IsOptional()
  @IsEnum(SchedulePriority)
  priority?: SchedulePriority

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isRemind?: boolean

  @ApiPropertyOptional({ example: 15 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  remindBefore?: number

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  completed?: boolean
}

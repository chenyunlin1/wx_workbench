import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator'
import { WorkoutIntensity, WorkoutType } from '../workout.entity'

export class CreateWorkoutDto {
  @ApiProperty({ enum: WorkoutType, example: WorkoutType.RUNNING })
  @IsEnum(WorkoutType)
  type: WorkoutType

  @ApiPropertyOptional({ example: '轻松跑 5 公里' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string

  @ApiProperty({ example: 45, minimum: 1, maximum: 1440 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1440)
  duration: number

  @ApiPropertyOptional({ example: 420, minimum: 0, maximum: 20000, nullable: true })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(20000)
  calories?: number | null

  @ApiPropertyOptional({ example: 5.2, minimum: 0, maximum: 1000, nullable: true })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(1000)
  distance?: number | null

  @ApiPropertyOptional({ enum: WorkoutIntensity, default: WorkoutIntensity.MEDIUM })
  @IsOptional()
  @IsEnum(WorkoutIntensity)
  intensity?: WorkoutIntensity

  @ApiProperty({ example: '2026-09-25T07:30:00+08:00' })
  @IsDateString()
  workoutDate: string

  @ApiPropertyOptional({ example: '配速 5:30，状态不错', nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string | null
}

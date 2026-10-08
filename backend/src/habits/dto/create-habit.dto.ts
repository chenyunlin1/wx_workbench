import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsInt, IsNotEmpty, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator'

export class CreateHabitDto {
  @ApiProperty({ example: '早起' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  name: string

  @ApiPropertyOptional({ example: '🌅' })
  @IsOptional()
  @IsString()
  @MaxLength(32)
  icon?: string

  @ApiPropertyOptional({ example: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000)
  streakDays?: number
}
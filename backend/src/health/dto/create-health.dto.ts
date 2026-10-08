import { ApiProperty } from '@nestjs/swagger'
import { IsDateString, IsNumber, Max, Min } from 'class-validator'

export class CreateHealthDto {
  @ApiProperty({ example: 72.5 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(20)
  @Max(300)
  weight: number

  @ApiProperty({ example: '2026-09-11' })
  @IsDateString()
  recordDate: string
}
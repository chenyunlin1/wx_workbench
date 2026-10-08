import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsDateString, IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator'
import { FinanceType } from '../../entities'

export class CreateFinanceDto {
  @ApiProperty({ enum: FinanceType, example: FinanceType.EXPENSE })
  @IsEnum(FinanceType)
  type: FinanceType

  @ApiProperty({ example: 68.5 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number

  @ApiProperty({ example: '餐饮' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  category: string

  @ApiPropertyOptional({ example: '和朋友吃饭' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  remark?: string

  @ApiProperty({ example: '2026-09-06T23:30:00+08:00' })
  @IsDateString()
  recordDate: string
}

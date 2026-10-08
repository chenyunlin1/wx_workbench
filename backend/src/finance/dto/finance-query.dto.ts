import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsEnum, IsInt, IsOptional, IsString, Matches, Max, Min } from 'class-validator'
import { FinanceType } from '../../entities'

export class FinanceQueryDto {
  @ApiPropertyOptional({ enum: FinanceType })
  @IsOptional()
  @IsEnum(FinanceType)
  type?: FinanceType

  @ApiPropertyOptional({ example: '餐饮' })
  @IsOptional()
  @IsString()
  category?: string

  @ApiPropertyOptional({ example: '2026-09' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}$/, { message: 'month 格式应为 YYYY-MM' })
  month?: string

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

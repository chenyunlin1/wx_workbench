import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator'
import { ShoppingStatus } from '../../entities'

export class CreateShoppingItemDto {
  @ApiProperty({ example: '机械键盘' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name: string

  @ApiPropertyOptional({ example: 399, default: 0 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  price?: number

  @ApiPropertyOptional({ enum: ShoppingStatus, default: ShoppingStatus.PENDING })
  @IsOptional()
  @IsEnum(ShoppingStatus)
  status?: ShoppingStatus
}
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator'

export class CreateOpsCommandDto {
  @ApiProperty({ example: '查看端口监听情况' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string

  @ApiProperty({ example: 'ss -tlnp' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  command: string

  @ApiPropertyOptional({ example: '3000 是后端、80 是 nginx，端口没起来先查这里' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string

  @ApiPropertyOptional({ example: '网络', default: '其他' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string
}

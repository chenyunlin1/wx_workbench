import { ApiPropertyOptional } from '@nestjs/swagger'
import { IsOptional, IsString, MaxLength } from 'class-validator'

/** 允许用未保存的临时配置测试连通性。 */
export class TestConnectionDto {
  @ApiPropertyOptional({ example: 'sk-xxxxxxxx' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiKey?: string

  @ApiPropertyOptional({ example: 'https://api.deepseek.com' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  baseUrl?: string

  @ApiPropertyOptional({ example: 'deepseek-chat' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  model?: string
}

import { ApiPropertyOptional } from '@nestjs/swagger'
import { IsOptional, IsString, Matches, MaxLength } from 'class-validator'

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: '阿云', description: '昵称，留空则回退显示用户名' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  nickname?: string

  @ApiPropertyOptional({ description: '头像：http(s) 图片地址或 data:image/...;base64 数据 URL；空串表示清除' })
  @IsOptional()
  @IsString()
  @MaxLength(60000)
  @Matches(/^$|^(https?:\/\/|data:image\/(png|jpe?g|webp|gif|bmp);base64,)/, {
    message: '头像格式仅支持图片地址或 base64 图片数据',
  })
  avatar?: string
}

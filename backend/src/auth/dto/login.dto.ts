import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator'
import { ApiProperty } from '@nestjs/swagger'

export class LoginDto {
  @ApiProperty({ example: 'admin' })
  @IsString()
  @IsNotEmpty({ message: '用户名不能为空' })
  @MaxLength(64)
  username: string

  @ApiProperty({ example: 'admin123' })
  @IsString()
  @MinLength(6, { message: '密码至少 6 位' })
  @MaxLength(100)
  password: string
}
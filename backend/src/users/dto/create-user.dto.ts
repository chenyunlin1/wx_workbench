import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsEnum, IsNotEmpty, IsOptional, IsString, IsUrl, MaxLength, MinLength } from 'class-validator'
import { UserRole } from '../../entities'

export class CreateUserDto {
  @ApiProperty({ example: 'zhangsan' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  username: string

  @ApiProperty({ example: 'password123' })
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  password: string

  @ApiPropertyOptional({ enum: UserRole, default: UserRole.USER })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole

  @ApiPropertyOptional({ example: 'https://example.com/avatar.png' })
  @IsOptional()
  @IsUrl({ require_protocol: true })
  avatar?: string
}
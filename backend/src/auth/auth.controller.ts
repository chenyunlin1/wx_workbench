import { Body, Controller, Get, Post, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { Public } from '../common/decorators/public.decorator'
import type { User } from '../entities'
import { AuthService } from './auth.service'
import { LoginDto } from './dto/login.dto'

@ApiTags('认证')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('login')
  @ApiOperation({ summary: '账号密码登录' })
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto)
  }

  @Get('profile')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取当前用户信息' })
  profile(@CurrentUser() user: User) {
    return user
  }
}
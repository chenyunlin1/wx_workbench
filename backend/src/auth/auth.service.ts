import { Injectable, UnauthorizedException } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { JwtService } from '@nestjs/jwt'
import * as bcrypt from 'bcryptjs'
import { UpdateProfileDto } from '../users/dto/update-profile.dto'
import { UsersService } from '../users/users.service'
import type { JwtPayload } from '../common/interfaces/api-response.interface'
import type { User } from '../entities'
import type { LoginDto } from './dto/login.dto'

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.usersService.findByUsernameWithPassword(dto.username)
    if (!user) throw new UnauthorizedException('用户名或密码错误')

    const isPasswordValid = await bcrypt.compare(dto.password, user.password)
    if (!isPasswordValid) throw new UnauthorizedException('用户名或密码错误')

    const { password: _password, ...safeUser } = user
    const tokens = await this.issueTokens(user)

    return { ...tokens, user: safeUser }
  }

  /**
   * 无感续期：只认登录时下发的 refreshToken（type=refresh），换发一对新令牌。
   * 刷新令牌本身过期或用户已不存在才失败，客户端据此才退回登录页。
   */
  async refresh(refreshToken: string) {
    const payload = await this.verifyRefreshToken(refreshToken)
    const user = await this.usersService.findById(payload.sub)
    if (!user) throw new UnauthorizedException('登录状态已失效')

    return this.issueTokens(user)
  }

  updateProfile(userId: number, dto: UpdateProfileDto) {
    return this.usersService.updateProfile(userId, dto)
  }

  /** accessToken 走全局 signOptions（JWT_EXPIRES_IN），refreshToken 单独给长有效期 */
  private async issueTokens(user: User) {
    const claims = { sub: user.id, username: user.username, role: user.role }
    const accessToken = await this.jwtService.signAsync(claims)
    const refreshToken = await this.jwtService.signAsync(
      { ...claims, type: 'refresh' },
      { expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '90d') as never },
    )

    return { accessToken, refreshToken }
  }

  private async verifyRefreshToken(token: string): Promise<JwtPayload> {
    let payload: JwtPayload
    try {
      payload = await this.jwtService.verifyAsync<JwtPayload>(token)
    } catch {
      throw new UnauthorizedException('登录状态已失效')
    }
    if (payload.type !== 'refresh' || !payload.sub) throw new UnauthorizedException('登录状态已失效')

    return payload
  }
}

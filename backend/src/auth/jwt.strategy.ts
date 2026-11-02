import { Injectable, UnauthorizedException } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PassportStrategy } from '@nestjs/passport'
import { ExtractJwt, Strategy } from 'passport-jwt'
import { UsersService } from '../users/users.service'
import type { JwtPayload } from '../common/interfaces/api-response.interface'

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET', 'life-workbench-dev-secret'),
    })
  }

  async validate(payload: JwtPayload) {
    // 刷新令牌只能走 /auth/refresh，拿它当 Bearer 访问业务接口一律拒绝
    if (payload.type === 'refresh') throw new UnauthorizedException('登录状态已失效')

    const user = await this.usersService.findById(payload.sub)
    if (!user) throw new UnauthorizedException('登录状态已失效')
    return user
  }
}
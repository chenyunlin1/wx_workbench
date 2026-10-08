import { createParamDecorator, type ExecutionContext } from '@nestjs/common'
import type { User } from '../../entities'

export const CurrentUser = createParamDecorator(
  (field: keyof User | undefined, context: ExecutionContext): User | User[keyof User] => {
    const request = context.switchToHttp().getRequest<{ user: User }>()
    return field ? request.user[field] : request.user
  },
)
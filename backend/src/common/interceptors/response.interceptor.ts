import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common'
import { Reflector } from '@nestjs/core'
import { map, type Observable } from 'rxjs'
import { RAW_RESPONSE_KEY } from '../decorators/raw-response.decorator'
import type { ApiResponse } from '../interfaces/api-response.interface'

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T> | T> {
  constructor(private readonly reflector: Reflector) {}

  intercept(context: ExecutionContext, next: CallHandler<T>): Observable<ApiResponse<T> | T> {
    const rawResponse = this.reflector.getAllAndOverride<boolean>(RAW_RESPONSE_KEY, [
      context.getHandler(),
      context.getClass(),
    ])

    if (rawResponse) return next.handle()

    return next.handle().pipe(
      map((data) => {
        if (data && typeof data === 'object' && 'code' in data && 'message' in data && 'data' in data) {
          return data as unknown as ApiResponse<T>
        }

        return {
          code: 0,
          message: 'success',
          data,
        }
      }),
    )
  }
}
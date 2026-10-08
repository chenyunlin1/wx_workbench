import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common'
import { QueryFailedError } from 'typeorm'
import type { Response } from 'express'

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name)

  catch(exception: unknown, host: ArgumentsHost) {
    const context = host.switchToHttp()
    const response = context.getResponse<Response>()
    let status = HttpStatus.INTERNAL_SERVER_ERROR
    let message = '服务器内部错误'

    if (exception instanceof HttpException) {
      status = exception.getStatus()
      const exceptionResponse = exception.getResponse()

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse
      } else if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
        const body = exceptionResponse as { message?: string | string[]; error?: string }
        message = Array.isArray(body.message)
          ? body.message.join('；')
          : body.message || body.error || message
      }
    } else if (exception instanceof QueryFailedError) {
      if (exception.message.includes('Duplicate entry')) {
        status = HttpStatus.CONFLICT
        message = '数据已存在，请勿重复提交'
      } else {
        this.logger.error(exception.message, exception.stack)
      }
    } else if (exception instanceof Error) {
      this.logger.error(exception.message, exception.stack)
    }

    response.status(status).json({
      code: status,
      message,
      data: null,
    })
  }
}
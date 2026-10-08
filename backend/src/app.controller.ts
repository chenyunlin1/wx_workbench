import { Controller, Get, Put } from '@nestjs/common'
import { ApiOperation, ApiTags } from '@nestjs/swagger'
import { Public } from './common/decorators/public.decorator'

@ApiTags('系统')
@Controller()
export class AppController {
  @Public()
  @Get('health')
  @ApiOperation({ summary: '服务健康检查' })
  health() {
    return {
      status: 'ok',
      service: 'life-workbench-api',
      timestamp: new Date().toISOString(),
    }
  }
}
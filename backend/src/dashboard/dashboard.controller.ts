import { Controller, Get, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { DashboardService } from './dashboard.service'

@ApiTags('今日概览')
@ApiBearerAuth()
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('summary')
  @ApiOperation({ summary: '获取今日概览聚合数据' })
  getSummary(@CurrentUser('id') userId: number) {
    return this.dashboardService.getSummary(userId)
  }
}
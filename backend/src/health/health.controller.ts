import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateHealthDto } from './dto/create-health.dto'
import { HealthTrendQueryDto } from './dto/health-trend-query.dto'
import { UpdateHealthDto } from './dto/update-health.dto'
import { HealthService } from './health.service'

@ApiTags('健康记录')
@ApiBearerAuth()
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  // 注意：GET /api/health 已被 AppController 的健康检查占用，这里用 /health/records 暴露列表
  @Get('records')
  @ApiOperation({ summary: '健康记录列表' })
  findAll(@CurrentUser('id') userId: number) {
    return this.healthService.findAll(userId)
  }

  @Get('trend')
  @ApiOperation({ summary: '体重趋势统计' })
  getTrend(@CurrentUser('id') userId: number, @Query() query: HealthTrendQueryDto) {
    return this.healthService.getTrend(userId, query.limit ?? 7)
  }

  @Get(':id')
  @ApiOperation({ summary: '健康记录详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.healthService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建健康记录' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateHealthDto) {
    return this.healthService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新健康记录' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateHealthDto,
  ) {
    return this.healthService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除健康记录' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.healthService.remove(id, userId)
  }
}
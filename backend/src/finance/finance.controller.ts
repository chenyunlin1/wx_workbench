import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateFinanceDto } from './dto/create-finance.dto'
import { FinanceQueryDto } from './dto/finance-query.dto'
import { FinanceStatsQueryDto } from './dto/finance-stats-query.dto'
import { UpdateFinanceDto } from './dto/update-finance.dto'
import { FinanceService } from './finance.service'

@ApiTags('记账理财')
@ApiBearerAuth()
@Controller('finance')
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Get()
  @ApiOperation({ summary: '分页查询财务记录' })
  findAll(@CurrentUser('id') userId: number, @Query() query: FinanceQueryDto) {
    return this.financeService.findAll(userId, query)
  }

  @Get('summary')
  @ApiOperation({ summary: '月度收入、支出和结余汇总' })
  getSummary(@CurrentUser('id') userId: number, @Query() query: FinanceStatsQueryDto) {
    return this.financeService.getSummary(userId, query.month)
  }

  @Get('stats')
  @ApiOperation({ summary: '月度收支统计和分类明细' })
  getStats(@CurrentUser('id') userId: number, @Query() query: FinanceStatsQueryDto) {
    return this.financeService.getStats(userId, query.month)
  }

  @Get('categories')
  @ApiOperation({ summary: '获取已使用的财务分类' })
  getCategories(@CurrentUser('id') userId: number) {
    return this.financeService.getCategories(userId)
  }

  @Get(':id')
  @ApiOperation({ summary: '财务记录详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.financeService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建财务记录' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateFinanceDto) {
    return this.financeService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新财务记录' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateFinanceDto,
  ) {
    return this.financeService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除财务记录' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.financeService.remove(id, userId)
  }
}

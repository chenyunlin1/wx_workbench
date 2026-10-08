import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateHabitDto } from './dto/create-habit.dto'
import {
  HabitRecordsQueryDto,
  HabitStatsQueryDto,
} from './dto/habit-records-query.dto'
import { UpdateHabitDto } from './dto/update-habit.dto'
import { HabitsService } from './habits.service'

@ApiTags('习惯打卡')
@ApiBearerAuth()
@Controller('habits')
export class HabitsController {
  constructor(private readonly habitsService: HabitsService) {}

  @Get()
  @ApiOperation({ summary: '习惯列表' })
  findAll(@CurrentUser('id') userId: number) {
    return this.habitsService.findAll(userId)
  }

  @Get('records')
  @ApiOperation({ summary: '日期范围内的打卡记录' })
  getRecords(@CurrentUser('id') userId: number, @Query() query: HabitRecordsQueryDto) {
    return this.habitsService.getRecords(userId, query.start, query.end)
  }

  @Get('stats')
  @ApiOperation({ summary: '打卡统计（今日完成率 / 近 N 天分布 / 每个习惯完成率）' })
  getStats(@CurrentUser('id') userId: number, @Query() query: HabitStatsQueryDto) {
    return this.habitsService.getStats(userId, query.days ?? 14)
  }

  @Get(':id')
  @ApiOperation({ summary: '习惯详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.habitsService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建习惯' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateHabitDto) {
    return this.habitsService.create(userId, dto)
  }

  @Post(':id/check-in')
  @ApiOperation({ summary: '今日打卡' })
  checkIn(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.habitsService.checkIn(id, userId)
  }

  @Delete(':id/check-in')
  @ApiOperation({ summary: '取消今日打卡' })
  cancelCheckIn(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.habitsService.cancelCheckIn(id, userId)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新习惯' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateHabitDto,
  ) {
    return this.habitsService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除习惯' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.habitsService.remove(id, userId)
  }
}
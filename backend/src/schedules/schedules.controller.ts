import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateScheduleDto } from './dto/create-schedule.dto'
import { ScheduleQueryDto } from './dto/schedule-query.dto'
import { UpdateScheduleDto } from './dto/update-schedule.dto'
import { SchedulesService } from './schedules.service'

@ApiTags('日程管理')
@ApiBearerAuth()
@Controller(['schedules', 'schedule'])
export class SchedulesController {
  constructor(private readonly schedulesService: SchedulesService) {}

  @Get()
  @ApiOperation({ summary: '按时间范围查询日程' })
  findAll(@CurrentUser('id') userId: number, @Query() query: ScheduleQueryDto) {
    return this.schedulesService.findAll(userId, query)
  }

  @Get(':id')
  @ApiOperation({ summary: '日程详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.schedulesService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建日程' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateScheduleDto) {
    return this.schedulesService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新日程' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateScheduleDto,
  ) {
    return this.schedulesService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除日程' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.schedulesService.remove(id, userId)
  }
}

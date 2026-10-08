import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateWorkoutDto } from './dto/create-workout.dto'
import { QueryWorkoutDto, WorkoutStatsQueryDto } from './dto/query-workout.dto'
import { UpdateWorkoutDto } from './dto/update-workout.dto'
import { WorkoutService } from './workout.service'

@ApiTags('健身训练')
@ApiBearerAuth()
@Controller('workout')
export class WorkoutController {
  constructor(private readonly workoutService: WorkoutService) {}

  @Get()
  @ApiOperation({ summary: '分页查询训练记录' })
  findAll(@CurrentUser('id') userId: number, @Query() query: QueryWorkoutDto) {
    return this.workoutService.findAll(userId, query)
  }

  @Get('stats')
  @ApiOperation({ summary: '训练统计（窗口汇总 / 近 N 天分布 / 类型分布 / 连续天数）' })
  getStats(@CurrentUser('id') userId: number, @Query() query: WorkoutStatsQueryDto) {
    return this.workoutService.getStats(userId, query.days)
  }

  @Get(':id')
  @ApiOperation({ summary: '训练记录详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.workoutService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '新增训练记录' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateWorkoutDto) {
    return this.workoutService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新训练记录' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateWorkoutDto,
  ) {
    return this.workoutService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除训练记录' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.workoutService.remove(id, userId)
  }
}

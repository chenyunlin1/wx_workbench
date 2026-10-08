import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateLearningTaskDto } from './dto/create-learning-task.dto'
import { UpdateLearningTaskDto } from './dto/update-learning-task.dto'
import { LearningService } from './learning.service'

@ApiTags('学习任务')
@ApiBearerAuth()
@Controller('learning')
export class LearningController {
  constructor(private readonly learningService: LearningService) {}

  @Get()
  @ApiOperation({ summary: '学习任务列表' })
  findAll(@CurrentUser('id') userId: number) {
    return this.learningService.findAll(userId)
  }

  @Get(':id')
  @ApiOperation({ summary: '学习任务详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.learningService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建学习任务' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateLearningTaskDto) {
    return this.learningService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新学习任务' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateLearningTaskDto,
  ) {
    return this.learningService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除学习任务' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.learningService.remove(id, userId)
  }
}
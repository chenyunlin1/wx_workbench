import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateInterviewDto } from './dto/create-interview.dto'
import { UpdateInterviewDto } from './dto/update-interview.dto'
import { InterviewsService } from './interviews.service'

@ApiTags('面试安排')
@ApiBearerAuth()
@Controller('interviews')
export class InterviewsController {
  constructor(private readonly interviewsService: InterviewsService) {}

  @Get()
  @ApiOperation({ summary: '面试列表' })
  findAll(@CurrentUser('id') userId: number) {
    return this.interviewsService.findAll(userId)
  }

  @Get(':id')
  @ApiOperation({ summary: '面试详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.interviewsService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建面试安排' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateInterviewDto) {
    return this.interviewsService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新面试安排' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateInterviewDto,
  ) {
    return this.interviewsService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除面试安排' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.interviewsService.remove(id, userId)
  }
}
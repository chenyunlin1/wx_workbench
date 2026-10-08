import { Body, Controller, Get, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import {
  GeneratePracticeDto,
  PracticeRangeQueryDto,
  SubmitPracticeResultDto,
} from './dto/generate-practice.dto'
import { PracticeService } from './practice.service'

@ApiTags('知识练习')
@ApiBearerAuth()
@Controller('practice')
export class PracticeController {
  constructor(private readonly practiceService: PracticeService) {}

  @Get('count')
  @ApiOperation({ summary: '获取当前练习范围的笔记总数' })
  count(@CurrentUser('id') userId: number, @Query() query: PracticeRangeQueryDto) {
    return this.practiceService.countByRange(userId, query.range)
  }

  @Get('generate')
  @ApiOperation({ summary: '生成闪卡或关键词填空练习' })
  generate(@CurrentUser('id') userId: number, @Query() dto: GeneratePracticeDto) {
    return this.practiceService.generate(userId, dto)
  }

  @Get('tags')
  @ApiOperation({ summary: '获取知识库已使用标签' })
  getTags(@CurrentUser('id') userId: number) {
    return this.practiceService.getTags(userId)
  }

  @Post('result')
  @ApiOperation({ summary: '汇总本次练习结果（不落库）' })
  submitResult(@Body() dto: SubmitPracticeResultDto) {
    return this.practiceService.submitResult(dto)
  }
}
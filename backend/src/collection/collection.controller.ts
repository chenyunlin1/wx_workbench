import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CollectionService } from './collection.service'
import { CollectionStatsQueryDto } from './dto/collection-stats-query.dto'
import { CreateCollectionDto } from './dto/create-collection.dto'
import { QueryCollectionDto } from './dto/query-collection.dto'
import { UpdateCollectionDto } from './dto/update-collection.dto'

@ApiTags('书影音收藏')
@ApiBearerAuth()
@Controller('collection')
export class CollectionController {
  constructor(private readonly collectionService: CollectionService) {}

  @Get()
  @ApiOperation({ summary: '分页查询收藏（按类型/状态/年份/关键词筛选）' })
  findAll(@CurrentUser('id') userId: number, @Query() query: QueryCollectionDto) {
    return this.collectionService.findAll(userId, query)
  }

  @Get('stats')
  @ApiOperation({ summary: '年度收藏统计' })
  getStats(@CurrentUser('id') userId: number, @Query() query: CollectionStatsQueryDto) {
    return this.collectionService.getStats(userId, query.year)
  }

  @Get('years')
  @ApiOperation({ summary: '可选统计年份' })
  getYears(@CurrentUser('id') userId: number) {
    return this.collectionService.getYears(userId)
  }

  @Get(':id')
  @ApiOperation({ summary: '收藏详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.collectionService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '新增收藏' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateCollectionDto) {
    return this.collectionService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新收藏' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateCollectionDto,
  ) {
    return this.collectionService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除收藏' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.collectionService.remove(id, userId)
  }
}

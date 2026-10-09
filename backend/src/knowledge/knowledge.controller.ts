import { BadRequestException, Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, Res, UploadedFile, UseInterceptors, Put } from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger'
import type { Response } from 'express'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { RawResponse } from '../common/decorators/raw-response.decorator'
import { UserRole } from '../entities/enums'
import { CreateKnowledgeDto } from './dto/create-knowledge.dto'
import { QueryKnowledgeDto } from './dto/query-knowledge.dto'
import { UpdateKnowledgeDto } from './dto/update-knowledge.dto'
import { KnowledgeService } from './knowledge.service'

@ApiTags('学习知识库')
@ApiBearerAuth()
@Controller('knowledge')
export class KnowledgeController {
  constructor(private readonly knowledgeService: KnowledgeService) {}

  @Get()
  @ApiOperation({ summary: '分页查询知识库' })
  findAll(@CurrentUser('id') userId: number, @Query() query: QueryKnowledgeDto) {
    return this.knowledgeService.findAll(userId, query)
  }

  @Get('tags')
  @ApiOperation({ summary: '获取已使用标签' })
  getTags(@CurrentUser('id') userId: number) {
    return this.knowledgeService.getTags(userId)
  }

  @Get('export')
  @RawResponse()
  @ApiOperation({ summary: '导出知识库 CSV' })
  async exportCsv(
    @CurrentUser('id') userId: number,
    @Query() query: QueryKnowledgeDto,
    @Res() response: Response,
  ) {
    const csv = await this.knowledgeService.exportCsv(userId, query)
    const filename = `knowledge-${new Date().toISOString().slice(0, 10)}.csv`
    response.setHeader('Content-Type', 'text/csv; charset=utf-8')
    response.setHeader('Content-Disposition', `attachment; filename="${filename}"`)
    response.send(csv)
  }

  @Post('import')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @ApiOperation({ summary: '导入知识库 CSV' })
  importCsv(
    @CurrentUser('id') userId: number,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('请选择 CSV 文件')
    return this.knowledgeService.importCsv(userId, file)
  }

  @Get(':id')
  @ApiOperation({ summary: '知识条目详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.knowledgeService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '新增知识条目' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateKnowledgeDto) {
    return this.knowledgeService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新知识条目或标记已学习' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @CurrentUser('role') role: UserRole,
    @Body() dto: UpdateKnowledgeDto,
  ) {
    return this.knowledgeService.update(id, userId, dto, role === UserRole.ADMIN)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除知识条目' })
  remove(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @CurrentUser('role') role: UserRole,
  ) {
    return this.knowledgeService.remove(id, userId, role === UserRole.ADMIN)
  }
}
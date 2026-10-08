import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateOpsCommandDto } from './dto/create-ops-command.dto'
import { UpdateOpsCommandDto } from './dto/update-ops-command.dto'
import { OpsService } from './ops.service'

@ApiTags('运维速查')
@ApiBearerAuth()
@Controller('ops')
export class OpsController {
  constructor(private readonly opsService: OpsService) {}

  @Get()
  @ApiOperation({ summary: '命令列表' })
  findAll(@CurrentUser('id') userId: number) {
    return this.opsService.findAll(userId)
  }

  @Get(':id')
  @ApiOperation({ summary: '命令详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.opsService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '新增命令' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateOpsCommandDto) {
    return this.opsService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新命令' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateOpsCommandDto,
  ) {
    return this.opsService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除命令' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.opsService.remove(id, userId)
  }
}

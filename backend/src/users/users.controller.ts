import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CreateUserDto } from './dto/create-user.dto'
import { UpdateUserDto } from './dto/update-user.dto'
import { UsersService } from './users.service'

@ApiTags('用户管理')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @ApiOperation({ summary: '用户列表' })
  findAll() {
    return this.usersService.findAll()
  }

  @Get(':id')
  @ApiOperation({ summary: '用户详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.findById(id)
  }

  @Post()
  @ApiOperation({ summary: '创建用户' })
  create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新用户' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateUserDto) {
    return this.usersService.update(id, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除用户' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.remove(id)
  }
}
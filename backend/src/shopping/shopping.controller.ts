import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Put } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { CreateShoppingItemDto } from './dto/create-shopping-item.dto'
import { UpdateShoppingItemDto } from './dto/update-shopping-item.dto'
import { ShoppingService } from './shopping.service'

@ApiTags('待买清单')
@ApiBearerAuth()
@Controller('shopping')
export class ShoppingController {
  constructor(private readonly shoppingService: ShoppingService) {}

  @Get()
  @ApiOperation({ summary: '待买清单' })
  findAll(@CurrentUser('id') userId: number) {
    return this.shoppingService.findAll(userId)
  }

  @Get(':id')
  @ApiOperation({ summary: '待买物品详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.shoppingService.findOne(id, userId)
  }

  @Post()
  @ApiOperation({ summary: '创建待买物品' })
  create(@CurrentUser('id') userId: number, @Body() dto: CreateShoppingItemDto) {
    return this.shoppingService.create(userId, dto)
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新待买物品' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser('id') userId: number,
    @Body() dto: UpdateShoppingItemDto,
  ) {
    return this.shoppingService.update(id, userId, dto)
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除待买物品' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser('id') userId: number) {
    return this.shoppingService.remove(id, userId)
  }
}
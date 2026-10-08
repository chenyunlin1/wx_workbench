import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { ShoppingItem } from '../entities'
import { CreateShoppingItemDto } from './dto/create-shopping-item.dto'
import { UpdateShoppingItemDto } from './dto/update-shopping-item.dto'

@Injectable()
export class ShoppingService {
  constructor(
    @InjectRepository(ShoppingItem)
    private readonly itemRepository: Repository<ShoppingItem>,
  ) {}

  findAll(userId: number) {
    return this.itemRepository.find({
      where: { userId },
      order: { id: 'DESC' },
    })
  }

  async findOne(id: number, userId: number) {
    const item = await this.itemRepository.findOne({ where: { id, userId } })
    if (!item) throw new NotFoundException('待买物品不存在')
    return item
  }

  create(userId: number, dto: CreateShoppingItemDto) {
    return this.itemRepository.save(this.itemRepository.create({ ...dto, userId }))
  }

  async update(id: number, userId: number, dto: UpdateShoppingItemDto) {
    const item = await this.findOne(id, userId)
    Object.assign(item, dto)
    return this.itemRepository.save(item)
  }

  async remove(id: number, userId: number) {
    const item = await this.findOne(id, userId)
    await this.itemRepository.remove(item)
    return { success: true }
  }
}
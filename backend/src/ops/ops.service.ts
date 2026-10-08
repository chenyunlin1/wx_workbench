import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { CreateOpsCommandDto } from './dto/create-ops-command.dto'
import { UpdateOpsCommandDto } from './dto/update-ops-command.dto'
import { OpsCommand } from './ops-command.entity'

@Injectable()
export class OpsService {
  constructor(
    @InjectRepository(OpsCommand)
    private readonly commandRepository: Repository<OpsCommand>,
  ) {}

  findAll(userId: number) {
    return this.commandRepository.find({
      where: { userId },
      order: { category: 'ASC', id: 'DESC' },
    })
  }

  async findOne(id: number, userId: number) {
    const item = await this.commandRepository.findOne({ where: { id, userId } })
    if (!item) throw new NotFoundException('命令不存在')
    return item
  }

  create(userId: number, dto: CreateOpsCommandDto) {
    return this.commandRepository.save(this.commandRepository.create({ ...dto, userId }))
  }

  async update(id: number, userId: number, dto: UpdateOpsCommandDto) {
    const item = await this.findOne(id, userId)
    Object.assign(item, dto)
    return this.commandRepository.save(item)
  }

  async remove(id: number, userId: number) {
    const item = await this.findOne(id, userId)
    await this.commandRepository.remove(item)
    return { success: true }
  }
}

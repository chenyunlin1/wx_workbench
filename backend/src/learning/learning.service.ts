import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { LearningTask } from '../entities'
import { CreateLearningTaskDto } from './dto/create-learning-task.dto'
import { UpdateLearningTaskDto } from './dto/update-learning-task.dto'

@Injectable()
export class LearningService {
  constructor(
    @InjectRepository(LearningTask)
    private readonly taskRepository: Repository<LearningTask>,
  ) {}

  findAll(userId: number) {
    return this.taskRepository.find({
      where: { userId },
      order: { id: 'DESC' },
    })
  }

  async findOne(id: number, userId: number) {
    const task = await this.taskRepository.findOne({ where: { id, userId } })
    if (!task) throw new NotFoundException('学习任务不存在')
    return task
  }

  create(userId: number, dto: CreateLearningTaskDto) {
    return this.taskRepository.save(this.taskRepository.create({ ...dto, userId }))
  }

  async update(id: number, userId: number, dto: UpdateLearningTaskDto) {
    const task = await this.findOne(id, userId)
    Object.assign(task, dto)
    return this.taskRepository.save(task)
  }

  async remove(id: number, userId: number) {
    const task = await this.findOne(id, userId)
    await this.taskRepository.remove(task)
    return { success: true }
  }
}
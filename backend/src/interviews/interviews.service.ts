import { Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { Interview } from '../entities'
import { CreateInterviewDto } from './dto/create-interview.dto'
import { UpdateInterviewDto } from './dto/update-interview.dto'

@Injectable()
export class InterviewsService {
  constructor(
    @InjectRepository(Interview)
    private readonly interviewRepository: Repository<Interview>,
  ) {}

  findAll(userId: number) {
    return this.interviewRepository.find({
      where: { userId },
      order: { interviewTime: 'DESC' },
    })
  }

  async findOne(id: number, userId: number) {
    const interview = await this.interviewRepository.findOne({ where: { id, userId } })
    if (!interview) throw new NotFoundException('面试安排不存在')
    return interview
  }

  create(userId: number, dto: CreateInterviewDto) {
    return this.interviewRepository.save(
      this.interviewRepository.create({
        ...dto,
        interviewTime: new Date(dto.interviewTime),
        userId,
      }),
    )
  }

  async update(id: number, userId: number, dto: UpdateInterviewDto) {
    const interview = await this.findOne(id, userId)
    Object.assign(interview, dto, {
      interviewTime: dto.interviewTime ? new Date(dto.interviewTime) : interview.interviewTime,
    })
    return this.interviewRepository.save(interview)
  }

  async remove(id: number, userId: number) {
    const interview = await this.findOne(id, userId)
    await this.interviewRepository.remove(interview)
    return { success: true }
  }
}
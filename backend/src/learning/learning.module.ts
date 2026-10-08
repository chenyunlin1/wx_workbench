import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { LearningTask } from '../entities'
import { LearningController } from './learning.controller'
import { LearningService } from './learning.service'

@Module({
  imports: [TypeOrmModule.forFeature([LearningTask])],
  controllers: [LearningController],
  providers: [LearningService],
  exports: [LearningService],
})
export class LearningModule {}
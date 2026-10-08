import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { Knowledge } from '../knowledge/knowledge.entity'
import { PracticeController } from './practice.controller'
import { PracticeService } from './practice.service'

@Module({
  imports: [TypeOrmModule.forFeature([Knowledge])],
  controllers: [PracticeController],
  providers: [PracticeService],
  exports: [PracticeService],
})
export class PracticeModule {}
import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { Habit, HabitRecord } from '../entities'
import { HabitsController } from './habits.controller'
import { HabitsService } from './habits.service'

@Module({
  imports: [TypeOrmModule.forFeature([Habit, HabitRecord])],
  controllers: [HabitsController],
  providers: [HabitsService],
  exports: [HabitsService],
})
export class HabitsModule {}
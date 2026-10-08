import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import {
  Finance,
  Habit,
  HabitRecord,
  Health,
  Interview,
  LearningTask,
  Schedule,
  ShoppingItem,
} from '../entities'
import { DashboardController } from './dashboard.controller'
import { DashboardService } from './dashboard.service'

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Schedule,
      Habit,
      HabitRecord,
      LearningTask,
      Interview,
      Finance,
      Health,
      ShoppingItem,
    ]),
  ],
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
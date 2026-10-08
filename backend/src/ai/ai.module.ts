import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { Collection } from '../collection/collection.entity'
import { CorosModule } from '../coros/coros.module'
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
import { Knowledge } from '../knowledge/knowledge.entity'
import { Workout } from '../workout/workout.entity'
import { AiContextService } from './ai-context.service'
import { AiConversation } from './ai-conversation.entity'
import { AiConversationService } from './ai-conversation.service'
import { AiMessage } from './ai-message.entity'
import { AiController } from './ai.controller'
import { AiService } from './ai.service'
import { AiSetting } from './ai-setting.entity'

@Module({
  imports: [
    CorosModule,
    TypeOrmModule.forFeature([
      AiSetting,
      AiConversation,
      AiMessage,
      Schedule,
      Habit,
      HabitRecord,
      LearningTask,
      Interview,
      Finance,
      Health,
      ShoppingItem,
      Knowledge,
      Collection,
      Workout,
    ]),
  ],
  controllers: [AiController],
  providers: [AiService, AiContextService, AiConversationService],
  exports: [AiService, AiContextService, AiConversationService],
})
export class AiModule {}

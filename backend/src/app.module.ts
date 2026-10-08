import { Module } from '@nestjs/common'
import { ConfigModule, ConfigService } from '@nestjs/config'
import { APP_GUARD } from '@nestjs/core'
import { TypeOrmModule } from '@nestjs/typeorm'
import { AiModule } from './ai/ai.module'
import { AiConversation } from './ai/ai-conversation.entity'
import { AiMessage } from './ai/ai-message.entity'
import { AiSetting } from './ai/ai-setting.entity'
import { AppController } from './app.controller'
import { AuthModule } from './auth/auth.module'
import { Collection } from './collection/collection.entity'
import { CollectionModule } from './collection/collection.module'
import { JwtAuthGuard } from './common/guards/jwt-auth.guard'
import { CorosActivity } from './coros/coros-activity.entity'
import { CorosConnection } from './coros/coros-connection.entity'
import { CorosDailyMetric } from './coros/coros-daily-metric.entity'
import { CorosModule } from './coros/coros.module'
import { CorosSnapshot } from './coros/coros-snapshot.entity'
import { DashboardModule } from './dashboard/dashboard.module'
import { SeedService } from './database/seed.service'
import {
  Finance,
  Habit,
  HabitRecord,
  Health,
  Interview,
  LearningTask,
  Schedule,
  ShoppingItem,
  User,
} from './entities'
import { FinanceModule } from './finance/finance.module'
import { HabitsModule } from './habits/habits.module'
import { HealthModule } from './health/health.module'
import { InterviewsModule } from './interviews/interviews.module'
import { Knowledge } from './knowledge/knowledge.entity'
import { KnowledgeModule } from './knowledge/knowledge.module'
import { LearningModule } from './learning/learning.module'
import { OpsCommand } from './ops/ops-command.entity'
import { OpsModule } from './ops/ops.module'
import { PracticeModule } from './practice/practice.module'
import { SchedulesModule } from './schedules/schedules.module'
import { ShoppingModule } from './shopping/shopping.module'
import { UsersModule } from './users/users.module'
import { Workout } from './workout/workout.entity'
import { WorkoutModule } from './workout/workout.module'

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', 'backend/.env'],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'mysql' as const,
        host: configService.get<string>('DB_HOST', '127.0.0.1'),
        port: configService.get<number>('DB_PORT', 3306),
        username: configService.get<string>('DB_USERNAME', 'root'),
        password: configService.get<string>('DB_PASSWORD', 'root'),
        database: configService.get<string>('DB_DATABASE', 'life_workbench'),
        entities: [
          User,
          Schedule,
          Habit,
          HabitRecord,
          LearningTask,
          Interview,
          Knowledge,
          Finance,
          Health,
          ShoppingItem,
          Collection,
          Workout,
          AiSetting,
          AiConversation,
          AiMessage,
          CorosConnection,
          CorosActivity,
          CorosDailyMetric,
          CorosSnapshot,
          OpsCommand,
        ],
        synchronize: configService.get<string>('NODE_ENV', 'development') !== 'production',
        logging: configService.get<string>('DB_LOGGING', 'false') === 'true',
        timezone: '+08:00',
        charset: 'utf8mb4',
        retryAttempts: 10,
        retryDelay: 3000,
      }),
    }),
    AuthModule,
    UsersModule,
    DashboardModule,
    AiModule,
    CollectionModule,
    CorosModule,
    SchedulesModule,
    HabitsModule,
    LearningModule,
    KnowledgeModule,
    PracticeModule,
    InterviewsModule,
    FinanceModule,
    HealthModule,
    ShoppingModule,
    WorkoutModule,
    OpsModule,
  ],
  controllers: [AppController],
  providers: [
    SeedService,
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}
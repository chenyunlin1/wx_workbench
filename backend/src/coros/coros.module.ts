import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { CorosActivity } from './coros-activity.entity'
import { CorosConnection } from './coros-connection.entity'
import { CorosDailyMetric } from './coros-daily-metric.entity'
import { CorosOAuthService } from './coros-oauth.service'
import { CorosSnapshot } from './coros-snapshot.entity'
import { CorosSyncService } from './coros-sync.service'
import { CorosController } from './coros.controller'
import { CorosService } from './coros.service'

@Module({
  imports: [TypeOrmModule.forFeature([CorosConnection, CorosActivity, CorosDailyMetric, CorosSnapshot])],
  controllers: [CorosController],
  providers: [CorosService, CorosOAuthService, CorosSyncService],
  exports: [CorosService],
})
export class CorosModule {}

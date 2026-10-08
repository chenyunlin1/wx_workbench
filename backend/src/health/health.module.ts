import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { Health } from '../entities'
import { HealthController } from './health.controller'
import { HealthService } from './health.service'

@Module({
  imports: [TypeOrmModule.forFeature([Health])],
  controllers: [HealthController],
  providers: [HealthService],
  exports: [HealthService],
})
export class HealthModule {}
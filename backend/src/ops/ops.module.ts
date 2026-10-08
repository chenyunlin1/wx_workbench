import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { OpsCommand } from './ops-command.entity'
import { OpsController } from './ops.controller'
import { OpsService } from './ops.service'

@Module({
  imports: [TypeOrmModule.forFeature([OpsCommand])],
  controllers: [OpsController],
  providers: [OpsService],
  exports: [OpsService],
})
export class OpsModule {}

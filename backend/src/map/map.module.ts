import { Module } from '@nestjs/common'
import { MapController } from './map.controller'
import { TileProxyService } from './tile-proxy.service'

@Module({
  controllers: [MapController],
  providers: [TileProxyService],
})
export class MapModule {}

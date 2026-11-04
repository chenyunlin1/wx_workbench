import { Controller, Get, Param, Req, Res } from '@nestjs/common'
import { ApiOperation, ApiTags } from '@nestjs/swagger'
import type { Request as ExpressRequest, Response as ExpressResponse } from 'express'
import { Public } from '../common/decorators/public.decorator'
import { RawResponse } from '../common/decorators/raw-response.decorator'
import { TILE_CACHE_TTL_MS } from './map.constants'
import { TileProxyService } from './tile-proxy.service'

/**
 * 地图瓦片是 <img> / ArkUI Image 直接发起的请求，带不上本系统的 JWT，
 * 所以这里必须 @Public；Key 藏在服务端，暴露的只有「图层 + 瓦片坐标」。
 */
@ApiTags('地图')
@Controller('map')
export class MapController {
  constructor(private readonly tiles: TileProxyService) {}

  @Public()
  @RawResponse()
  @Get('tile/:layer/:zoom/:x/:y')
  @ApiOperation({ summary: '天地图瓦片代理（底图与注记都走这里，Key 不下发）' })
  async tile(
    @Param('layer') layer: string,
    @Param('zoom') zoom: string,
    @Param('x') x: string,
    @Param('y') y: string,
    @Req() request: ExpressRequest,
    @Res() response: ExpressResponse,
  ) {
    const tile = await this.tiles.tile(layer, zoom, x, y, request.ip ?? '')

    response.setHeader('Content-Type', tile.mime)
    response.setHeader(
      'Cache-Control',
      tile.fallback ? 'no-store' : `public, max-age=${Math.floor(TILE_CACHE_TTL_MS / 1000)}`,
    )
    response.setHeader('Content-Length', tile.bytes.length)
    response.status(200).end(tile.bytes)
  }
}

import { Body, Controller, Delete, Get, Post, Query, Req, Res } from '@nestjs/common'
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger'
import type { Request as ExpressRequest, Response as ExpressResponse } from 'express'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { Public } from '../common/decorators/public.decorator'
import { RawResponse } from '../common/decorators/raw-response.decorator'
import { CorosSyncService } from './coros-sync.service'
import { CorosService } from './coros.service'
import { SyncCorosDto } from './dto/sync-coros.dto'

/**
 * 高驰 MCP 走标准 OAuth 2.1 授权码 + PKCE：
 * 授权页在高驰域名下，回跳时浏览器不会带本系统的 JWT，
 * 所以 callback 是 @Public 的，靠 state 找回是哪个用户在授权。
 */
@ApiTags('高驰 MCP')
@ApiBearerAuth()
@Controller('coros')
export class CorosController {
  constructor(
    private readonly corosService: CorosService,
    private readonly syncService: CorosSyncService,
  ) {}

  @Get('status')
  @ApiOperation({ summary: '高驰连接状态与已发现的工具清单' })
  status(@CurrentUser('id') userId: number) {
    return this.corosService.status(userId)
  }

  @Post('connect')
  @ApiOperation({ summary: '发起授权，返回高驰登录/授权页地址' })
  connect(@CurrentUser('id') userId: number, @Req() request: ExpressRequest) {
    return this.corosService.connect(userId, request)
  }

  @Public()
  @RawResponse()
  @Get('callback')
  @ApiOperation({ summary: '高驰授权回跳地址（浏览器访问，处理后 302 回前端）' })
  async callback(
    @Res() response: ExpressResponse,
    @Query('code') code?: string,
    @Query('state') state?: string,
    @Query('error') error?: string,
    @Query('error_description') errorDescription?: string,
  ) {
    const origin = this.corosService.webOrigin()

    try {
      if (error) throw new Error(errorDescription || `高驰授权被拒绝（${error}）`)
      if (!code || !state) throw new Error('授权回跳缺少 code 或 state')

      const result = await this.corosService.completeAuthorize(code, state)
      const warning = result.warning ? `&message=${encodeURIComponent(result.warning)}` : ''
      response.redirect(`${origin}/running?coros=connected${warning}`)
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : '授权失败'
      response.redirect(`${origin}/running?coros=failed&message=${encodeURIComponent(message)}`)
    }
  }

  @Delete('connection')
  @ApiOperation({ summary: '解绑高驰账号（撤销令牌并清空本地授权）' })
  disconnect(@CurrentUser('id') userId: number) {
    return this.corosService.disconnect(userId)
  }

  @Post('tools/refresh')
  @ApiOperation({ summary: '重新拉取 tools/list（高驰新增工具后点这里）' })
  refreshTools(@CurrentUser('id') userId: number) {
    return this.corosService.syncTools(userId)
  }

  @Post('sync')
  @ApiOperation({ summary: '把高驰数据拉到本地库（后台执行，进度看 status）' })
  sync(@CurrentUser('id') userId: number, @Body() dto: SyncCorosDto) {
    return this.syncService.start(userId, dto.days)
  }

  @Get('dashboard')
  @ApiQuery({ name: 'days', required: false, example: 30 })
  @ApiOperation({ summary: '跑步专项看板：本地已同步的活动、逐日指标与状态快照' })
  dashboard(@CurrentUser('id') userId: number, @Query('days') days?: string) {
    return this.syncService.dashboard(userId, days ? Number(days) : undefined)
  }
}

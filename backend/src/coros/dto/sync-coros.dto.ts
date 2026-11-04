import { ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator'
import { COROS_SYNC_DEFAULT_DAYS, COROS_SYNC_MAX_DAYS } from '../coros.constants'

export class SyncCorosDto {
  @ApiPropertyOptional({
    example: 30,
    default: COROS_SYNC_DEFAULT_DAYS,
    description: `拉取最近多少天的数据（最多 ${COROS_SYNC_MAX_DAYS}）`,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(COROS_SYNC_MAX_DAYS)
  days?: number

  @ApiPropertyOptional({
    example: false,
    description: 'true = 从今天往前逐月翻完全部历史运动记录（轨迹仍按每日限额分批补）',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  history?: boolean
}

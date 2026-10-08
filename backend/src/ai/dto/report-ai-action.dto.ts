import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator'

export const AI_ACTION_REPORT_STATUS = ['done', 'failed', 'cancelled'] as const
export type AiActionReportStatus = (typeof AI_ACTION_REPORT_STATUS)[number]

/** 客户端执行完某个工具调用后回写的结果 */
export class ReportAiActionDto {
  @ApiProperty({ example: 0, description: '该消息内 actions 数组的下标' })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  index: number

  @ApiProperty({ enum: AI_ACTION_REPORT_STATUS, example: 'done' })
  @IsIn(AI_ACTION_REPORT_STATUS)
  status: AiActionReportStatus

  @ApiPropertyOptional({ example: '分类已存在' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  error?: string
}

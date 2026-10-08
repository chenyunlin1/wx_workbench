import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator'
import { InterviewStatus } from '../../entities'

export class CreateInterviewDto {
  @ApiProperty({ example: '星河科技' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  company: string

  @ApiProperty({ example: '高级前端工程师' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  position: string

  @ApiProperty({ example: '2026-09-15T14:00:00+08:00' })
  @IsDateString()
  interviewTime: string

  @ApiPropertyOptional({ enum: InterviewStatus, default: InterviewStatus.PENDING })
  @IsOptional()
  @IsEnum(InterviewStatus)
  status?: InterviewStatus
}
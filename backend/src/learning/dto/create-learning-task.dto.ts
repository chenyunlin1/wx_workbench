import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, Min } from 'class-validator'
import { LearningStatus } from '../../entities'

export class CreateLearningTaskDto {
  @ApiProperty({ example: 'JVM 调优：GC 与内存模型' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(180)
  title: string

  @ApiPropertyOptional({ example: 45, default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  duration?: number

  @ApiPropertyOptional({ enum: LearningStatus, default: LearningStatus.TODO })
  @IsOptional()
  @IsEnum(LearningStatus)
  status?: LearningStatus
}
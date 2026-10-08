import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger'
import { Type } from 'class-transformer'
import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator'

export enum PracticeMode {
  FLASHCARD = 'flashcard',
  FILLBLANK = 'fillblank',
}

export enum PracticeResultLevel {
  REMEMBERED = 'remembered',
  FUZZY = 'fuzzy',
  FORGOTTEN = 'forgotten',
}

export class GeneratePracticeDto {
  @ApiProperty({ enum: PracticeMode, example: PracticeMode.FLASHCARD })
  @IsEnum(PracticeMode)
  mode: PracticeMode

  @ApiProperty({ example: 'all', description: 'all、learned、unlearned，或知识库中的具体标签' })
  @IsString()
  @IsNotEmpty()
  range: string

  @ApiProperty({ example: 10, enum: [5, 10, 20, 50] })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  count: number
}

export class PracticeRangeQueryDto {
  @ApiPropertyOptional({ example: 'all', default: 'all' })
  @IsOptional()
  @IsString()
  range = 'all'
}

export class SubmitPracticeResultDto {
  @ApiProperty({ enum: PracticeMode })
  @IsEnum(PracticeMode)
  mode: PracticeMode

  @ApiProperty({ example: 10 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  total: number

  @ApiProperty({ example: 6 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  remembered: number

  @ApiProperty({ example: 2 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  fuzzy: number

  @ApiProperty({ example: 2 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  forgotten: number

  @ApiProperty({ example: 96 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  duration: number
}
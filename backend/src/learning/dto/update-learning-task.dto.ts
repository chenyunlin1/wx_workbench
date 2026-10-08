import { PartialType } from '@nestjs/swagger'
import { CreateLearningTaskDto } from './create-learning-task.dto'

export class UpdateLearningTaskDto extends PartialType(CreateLearningTaskDto) {}
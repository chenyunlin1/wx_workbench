import { PartialType } from '@nestjs/swagger'
import { CreateOpsCommandDto } from './create-ops-command.dto'

export class UpdateOpsCommandDto extends PartialType(CreateOpsCommandDto) {}

import { Module } from '@nestjs/common'
import { TypeOrmModule } from '@nestjs/typeorm'
import { ShoppingItem } from '../entities'
import { ShoppingController } from './shopping.controller'
import { ShoppingService } from './shopping.service'

@Module({
  imports: [TypeOrmModule.forFeature([ShoppingItem])],
  controllers: [ShoppingController],
  providers: [ShoppingService],
  exports: [ShoppingService],
})
export class ShoppingModule {}
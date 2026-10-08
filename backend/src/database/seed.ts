import { NestFactory } from '@nestjs/core'
import { AppModule } from '../app.module'

async function seed() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  })
  await app.close()
}

void seed()
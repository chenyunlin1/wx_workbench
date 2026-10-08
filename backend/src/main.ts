import { Logger, ValidationPipe } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { NestFactory, Reflector } from '@nestjs/core'
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger'
import { AppModule } from './app.module'
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter'
import { ResponseInterceptor } from './common/interceptors/response.interceptor'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)
  const configService = app.get(ConfigService)
  const port = configService.get<number>('PORT', 3000)
  const apiPrefix = configService.get<string>('API_PREFIX', 'api')
  const corsOrigins = configService
    .get<string>('CORS_ORIGINS', 'http://localhost:5173')
    .split(',')
    .map((origin) => origin.trim())

  app.setGlobalPrefix(apiPrefix)
  app.enableCors({
    origin: corsOrigins.includes('*') ? true : corsOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  )
  app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)))
  app.useGlobalFilters(new AllExceptionsFilter())
  app.getHttpAdapter().getInstance().disable('x-powered-by')

  const swaggerConfig = new DocumentBuilder()
    .setTitle('个人生活工作台 API')
    .setDescription('LifeOS 全栈接口文档：认证、日程、习惯、学习、财务、健康与待买清单。')
    .setVersion('1.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'Authorization',
        in: 'header',
      },
      'bearer',
    )
    .build()
  const document = SwaggerModule.createDocument(app, swaggerConfig)
  SwaggerModule.setup('docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
      tagsSorter: 'alpha',
    },
  })

  await app.listen(port, '0.0.0.0')
  Logger.log(`API: http://localhost:${port}/${apiPrefix}`, 'Bootstrap')
  Logger.log(`Swagger: http://localhost:${port}/docs`, 'Bootstrap')
}

void bootstrap()
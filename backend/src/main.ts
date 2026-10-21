// Nạp .env trước khi import module: decorator @Module đọc process.env lúc import.
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import helmet from 'helmet';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  const isProduction = process.env.NODE_ENV === 'production';
  // Sau reverse proxy (TRUST_PROXY=1) để throttler lấy đúng IP client.
  if (process.env.TRUST_PROXY) app.set('trust proxy', Number(process.env.TRUST_PROXY) || 1);

  // Middleware
  app.use(helmet());
  // Ảnh base64 tối đa ~10MB (MAX_FILE_SIZE) → ~14MB JSON.
  app.useBodyParser('json', { limit: '15mb' });
  app.useBodyParser('urlencoded', { limit: '1mb', extended: true });

  // Global prefix
  const apiPrefix = process.env.API_PREFIX || 'api';
  app.setGlobalPrefix(apiPrefix);

  // CORS
  app.enableCors({
    origin: (process.env.CORS_ORIGIN || 'http://localhost:3000').split(','),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Delete-All'],
  });

  // Validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Swagger chỉ bật ngoài production để không lộ bản đồ API.
  if (!isProduction) {
    const config = new DocumentBuilder()
      .setTitle('Moodi API')
      .setDescription('Moodi - Social Wellness App API Documentation')
      .setVersion('1.0.0')
      .addBearerAuth()
      .build();

    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document);
  }

  const port = process.env.PORT || 3000;
  await app.listen(port);

  console.log(`🚀 Moodi API is running on http://localhost:${port}`);
  if (!isProduction) {
    console.log(`📚 Swagger docs available at http://localhost:${port}/docs`);
  }
}

bootstrap();

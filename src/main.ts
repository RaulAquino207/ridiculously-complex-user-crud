import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('Ridiculously Complex User CRUD')
      .setDescription('The user API description')
      .setVersion('1.0')
      .addTag('users')
      .build();

    const documentFactory = () => SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('swagger', app, documentFactory);
    Logger.warn(
      `Aplication is running in ${process.env.NODE_ENV} mode. Documentation available at http://localhost:${process.env.PORT ?? 3000}/swagger`,
      'Bootstrap',
    );
  }

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();

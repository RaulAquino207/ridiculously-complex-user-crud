import { Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { DATABASE_INITIALIZER_TOKEN } from './interfaces/database-initializer.interface';
import { DynamoDBInitializer } from 'src/infra/database/initializers/dynamodb.initializer';

@Module({
  providers: [
    {
      provide: DATABASE_INITIALIZER_TOKEN,
      useClass: DynamoDBInitializer,
    },
    DatabaseService,
  ],
  exports: [DatabaseService],
})
export class DatabaseModule {}

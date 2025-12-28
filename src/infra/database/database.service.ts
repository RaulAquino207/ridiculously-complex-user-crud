import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DATABASE_INITIALIZER_TOKEN, type DatabaseInitializer } from './interfaces/database-initializer.interface';

@Injectable()
export class DatabaseService implements OnModuleInit {
  private readonly logger = new Logger(DatabaseService.name);

  constructor(
    @Inject(DATABASE_INITIALIZER_TOKEN)
    private readonly initializer: DatabaseInitializer,
  ) {}

  async onModuleInit() {
    if (process.env.NODE_ENV === 'production') {
      this.logger.log(
        '🏭 Production environment - skipping automatic table initialization',
      );
      return;
    }

    try {
      this.logger.log('🚀 Initializing database tables...');
      await this.initializer.initialize();
      this.logger.log('✅ Database initialization completed');
    } catch (error) {
      this.logger.error(
        '❌ Failed to initialize database tables',
        error instanceof Error ? error.stack : String(error),
      );
      throw error;
    }
  }
}

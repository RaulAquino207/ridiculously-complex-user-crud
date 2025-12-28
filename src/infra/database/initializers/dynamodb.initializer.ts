import { Injectable, Logger } from '@nestjs/common';
import {
  CreateTableCommand,
  DescribeTableCommand,
  DynamoDBClient,
  ListTablesCommand,
} from '@aws-sdk/client-dynamodb';
import { dynamoDBBaseClient } from 'src/config/aws-config/dynamoDBClient';
import { DatabaseInitializer } from '../interfaces/database-initializer.interface';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class DynamoDBInitializer implements DatabaseInitializer {
  private readonly logger = new Logger(DynamoDBInitializer.name);
  private readonly client: DynamoDBClient;

  constructor() {
    this.client = dynamoDBBaseClient();
  }

  async initialize(): Promise<void> {
    const tablesDir = this.resolveTablesDirectory();

    if (!tablesDir) {
      this.logger.warn('⚠️ Tables directory not found. Skipping table creation.');
      return;
    }

    const tableFiles = fs
      .readdirSync(tablesDir)
      .filter((file) => file.endsWith('.json'));

    if (tableFiles.length === 0) {
      this.logger.warn(
        `⚠️ No table definition files found in ${tablesDir}. Skipping table creation.`,
      );
      return;
    }

    this.logger.log(`📋 Found ${tableFiles.length} table definition(s)`);

    for (const file of tableFiles) {
      await this.processTableDefinition(tablesDir, file);
    }
  }

  private resolveTablesDirectory(): string | null {
    const candidateDirs = [
      process.env.DYNAMO_TABLES_DIR,
      path.resolve(process.cwd(), 'src/infra/dynamo/tables'),
      path.resolve(process.cwd(), 'dist/infra/dynamo/tables'),
    ].filter(Boolean) as string[];

    const foundDir = candidateDirs.find((dir) => fs.existsSync(dir));

    if (!foundDir) {
      this.logger.debug(
        `🔍 Searched paths: ${candidateDirs.join(', ')} - none found`,
      );
    }

    return foundDir || null;
  }

  private async processTableDefinition(
    tablesDir: string,
    file: string,
  ): Promise<void> {
    const filePath = path.join(tablesDir, file);

    try {
      const tableDefinition = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
      const tableName = tableDefinition.TableName;

      if (!tableName) {
        this.logger.error(`❌ Table definition in ${file} missing TableName`);
        return;
      }

      const exists = await this.tableExists(tableName);

      if (exists) {
        const status = await this.getTableStatus(tableName);
        this.logger.log(
          `✅ Table "${tableName}" already exists (status: ${status})`,
        );
        return;
      }

      await this.createTable(tableDefinition);
      await this.waitForTableActive(tableName);
      this.logger.log(`✅ Table "${tableName}" created successfully`);
    } catch (error) {
      this.logger.error(
        `❌ Error processing table from ${file}:`,
        error instanceof Error ? error.message : String(error),
      );
      throw error;
    }
  }

  private async tableExists(tableName: string): Promise<boolean> {
    try {
      const result = await this.client.send(new ListTablesCommand({}));
      return result.TableNames?.includes(tableName) ?? false;
    } catch (error) {
      this.logger.error(
        `❌ Error checking if table exists:`,
        error instanceof Error ? error.message : String(error),
      );
      return false;
    }
  }

  private async getTableStatus(tableName: string): Promise<string> {
    try {
      const result = await this.client.send(
        new DescribeTableCommand({ TableName: tableName }),
      );
      return result.Table?.TableStatus || 'UNKNOWN';
    } catch {
      return 'ERROR';
    }
  }

  private async createTable(tableDefinition: any): Promise<void> {
    this.logger.log(`🔄 Creating table "${tableDefinition.TableName}"...`);
    await this.client.send(new CreateTableCommand(tableDefinition));
  }

  private async waitForTableActive(
    tableName: string,
    maxAttempts = 30,
  ): Promise<void> {
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const result = await this.client.send(
          new DescribeTableCommand({ TableName: tableName }),
        );

        if (result.Table?.TableStatus === 'ACTIVE') {
          return;
        }

        await new Promise((resolve) => setTimeout(resolve, 500));
      } catch (error) {
        if (attempt === maxAttempts) {
          throw new Error(
            `Table "${tableName}" did not become active within expected time.`,
          );
        }
      }
    }
  }
}

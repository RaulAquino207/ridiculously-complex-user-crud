import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  async healthCheck(): Promise<{ status: string }> {
    return { status: 'healthy' };
  }
}

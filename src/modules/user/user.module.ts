import { Module } from '@nestjs/common';
import { UserService } from './user.service';
import { UserController } from './user.controller';
import { USER_GATEWAY_TOKEN } from 'src/domain/user/gateway/user.gateway';
import { UserRepositoryDynamo } from 'src/infra/repositories/user.repository.dynamo';

@Module({
  controllers: [UserController],
  providers: [
    UserService,
    {
      provide: USER_GATEWAY_TOKEN,
      useClass: UserRepositoryDynamo,
    },
  ],
})
export class UserModule {}

import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { dynamoDBClient } from 'src/config/aws-config/dynamoDBClient';
import { User } from 'src/domain/user/entity/user';
import { UserGateway } from 'src/domain/user/gateway/user.gateway';
import { v4 as uuid } from 'uuid';

const { DYNAMODB_TABLE_USERS } = process.env;

export class UserRepositoryDynamo implements UserGateway {
  async create(): Promise<User> {
    const id = uuid();
    const client = dynamoDBClient();
    
    const userData = {
      id,
      name: 'Raul',
      email: 'aquinoraul207@gmail.com',
    };

    await client.send(
      new PutCommand({
        TableName: DYNAMODB_TABLE_USERS!,
        Item: userData,
      }),
    );

    return User.with({
      id: userData.id,
      name: userData.name,
      email: userData.email,
    });
  }
}

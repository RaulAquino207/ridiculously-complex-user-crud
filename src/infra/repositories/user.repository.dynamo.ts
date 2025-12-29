import { GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { NotFoundException } from '@nestjs/common';
import { dynamoDBClient } from 'src/config/aws-config/dynamoDBClient';
import { User } from 'src/domain/user/entity/user';
import { UserGateway } from 'src/domain/user/gateway/user.gateway';
import { CreateUserDto } from 'src/modules/user/dto/create-user.dto';
import { v4 as uuid } from 'uuid';

const { DYNAMODB_TABLE_USERS } = process.env;

export class UserRepositoryDynamo implements UserGateway {
  async create(createUserDto: CreateUserDto): Promise<User> {
    const id = uuid();
    const client = dynamoDBClient();
    
    const userData = {
      id,
      name: createUserDto.name,
      email: createUserDto.email,
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

  async findOne(id: string): Promise<User> {
    const client = dynamoDBClient();

    const result = await client.send(new GetCommand({
      TableName: DYNAMODB_TABLE_USERS!,
      Key: { id },
    }));

    if (!result.Item) {
      throw new NotFoundException(`User with id ${id} not found`);
    }

    return User.with({
      id: result.Item.id,
      name: result.Item.name,
      email: result.Item.email,
    });
  }
}

import { Inject, Injectable } from '@nestjs/common';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { USER_GATEWAY_TOKEN, type UserGateway } from 'src/domain/user/gateway/user.gateway';



@Injectable()
export class UserService {

  constructor(
    @Inject(USER_GATEWAY_TOKEN) private readonly userRepository: UserGateway
  ) {}

  async create(createUserDto: CreateUserDto) {
    
    return this.userRepository.create();
  }

  findAll() {
    return `This action returns all user`;
  }

  findOne(id: number) {
    return `This action returns a #${id} user`;
  }

  update(id: number, updateUserDto: UpdateUserDto) {
    return `This action updates a #${id} user`;
  }

  remove(id: number) {
    return `This action removes a #${id} user`;
  }
}

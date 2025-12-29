import { User } from "src/domain/user/entity/user";
import { CreateUserDto } from "src/modules/user/dto/create-user.dto";

export interface UserGateway {
    create(createUserDto: CreateUserDto): Promise<User>;
    // findAll(): Promise<Array<User>>;
    findOne(id: string): Promise<User>;
    // update(): Promise<User>;
    // remove(): Promise<User>;
}

export const USER_GATEWAY_TOKEN = "UserGateway";
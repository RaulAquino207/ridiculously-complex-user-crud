import { User } from "src/domain/user/entity/user";

export interface UserGateway {
    create(): Promise<User>;
    // findAll(): Promise<Array<User>>;
    // findOne(id: string): Promise<User>;
    // update(): Promise<User>;
    // remove(): Promise<User>;
}

export const USER_GATEWAY_TOKEN = "UserGateway";
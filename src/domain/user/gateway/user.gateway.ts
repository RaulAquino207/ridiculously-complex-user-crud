import { User } from "src/domain/user/entity/user";

export interface UserGateway {
    save(): Promise<User>;
    list(): Promise<Array<User>>;
    getOne(id: string): Promise<User>;
}
import { IsEmail, IsString } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class CreateUserDto {
    @ApiProperty({ example: 'John Doe', required: true })
    @IsString()
    name: string;

    @ApiProperty({ example: 'john.doe@example.com', required: true })
    @IsEmail()
    email: string;
}

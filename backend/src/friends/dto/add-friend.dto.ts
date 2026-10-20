import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AddFriendDto {
  @ApiProperty({ example: 'uuid-of-user' })
  @IsUUID()
  friendId: string;
}

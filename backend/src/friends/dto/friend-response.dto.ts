import { ApiProperty } from '@nestjs/swagger';

export class FriendResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  userId: string;

  @ApiProperty()
  friendId: string;

  @ApiProperty()
  friend: {
    id: string;
    username: string;
    displayName: string;
    avatar: string;
  };

  @ApiProperty()
  status: string;

  @ApiProperty()
  createdAt: Date;

  @ApiProperty()
  updatedAt: Date;
}

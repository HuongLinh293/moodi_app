import { ApiProperty } from '@nestjs/swagger';

export class FriendRequestResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  senderId: string;

  @ApiProperty()
  sender: {
    id: string;
    username: string;
    displayName: string;
    avatar: string;
  };

  @ApiProperty()
  recipientId: string;

  @ApiProperty()
  createdAt: Date;
}

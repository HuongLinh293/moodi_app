import { ApiProperty } from '@nestjs/swagger';

export class MessageResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  conversationId: string;

  @ApiProperty()
  sender: {
    id: string;
    username: string;
    displayName: string;
    avatar: string;
  };

  @ApiProperty()
  content: string;

  @ApiProperty()
  imageUrls: string[];

  @ApiProperty()
  isEdited: boolean;

  @ApiProperty()
  createdAt: Date;

  @ApiProperty()
  editedAt: Date;
}

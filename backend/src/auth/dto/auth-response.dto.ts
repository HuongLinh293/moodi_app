import { ApiProperty } from '@nestjs/swagger';

class UserDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  email: string;

  @ApiProperty()
  username: string;

  @ApiProperty({ required: false })
  displayName?: string;

  @ApiProperty({ required: false })
  avatar?: string;
}

export class AuthResponseDto {
  @ApiProperty()
  user: UserDto;

  @ApiProperty()
  accessToken: string;

  @ApiProperty()
  refreshToken: string;

  @ApiProperty()
  expiresAt: number;
}

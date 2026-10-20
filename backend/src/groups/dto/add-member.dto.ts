import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AddMemberDto {
  @ApiProperty({ example: 'uuid-of-user' })
  @IsUUID()
  userId: string;
}

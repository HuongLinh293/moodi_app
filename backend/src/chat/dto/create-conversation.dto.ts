import { IsString, IsArray, IsUUID, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateConversationDto {
  @ApiProperty({ example: 'direct', enum: ['direct', 'group'] })
  @IsEnum(['direct', 'group'])
  type: string;

  @ApiProperty({ example: 'Nhóm chat' })
  @IsString()
  name?: string;

  @ApiProperty({ example: ['uuid-of-user-1', 'uuid-of-user-2'] })
  @IsArray()
  @IsUUID('all', { each: true })
  participantIds: string[];
}

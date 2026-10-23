import { IsString, IsArray, IsUUID, IsEnum, IsOptional, MaxLength, ArrayMaxSize, ArrayMinSize } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateConversationDto {
  @ApiProperty({ example: 'direct', enum: ['direct', 'group'] })
  @IsEnum(['direct', 'group'])
  type: string;

  @ApiProperty({ example: 'Nhóm chat', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiProperty({ example: ['uuid-of-user-1', 'uuid-of-user-2'] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(49)
  @IsUUID('all', { each: true })
  participantIds: string[];
}

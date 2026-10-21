import { IsString, IsOptional, IsEnum, IsUUID, IsIn, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UploadFileDto {
  @ApiProperty({ example: 'photo.jpg' })
  @IsString()
  @MaxLength(255)
  filename: string;

  @ApiProperty({ example: 'base64_encoded_file_content' })
  @IsString()
  fileContent: string;

  @ApiProperty({
    example: 'image/jpeg',
    enum: ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf'],
  })
  @IsIn(['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf'])
  mimeType: string;

  @ApiProperty({ example: 'private', enum: ['public', 'private'], required: false })
  @IsEnum(['public', 'private'])
  @IsOptional()
  accessType?: string;

  @ApiProperty({ example: 'post', enum: ['post', 'message', 'avatar', 'group'], required: false })
  @IsOptional()
  @IsIn(['post', 'message', 'avatar', 'group'])
  relatedEntityType?: string;

  @ApiProperty({ example: 'uuid-of-post', required: false })
  @IsOptional()
  @IsUUID()
  relatedEntityId?: string;
}

import { IsString, IsOptional, IsEnum, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UploadFileDto {
  @ApiProperty({ example: 'file.pdf' })
  @IsString()
  filename: string;

  @ApiProperty({ example: 'base64_encoded_file_content' })
  @IsString()
  fileContent: string;

  @ApiProperty({ example: 'application/pdf' })
  @IsString()
  @IsOptional()
  mimeType?: string;

  @ApiProperty({ example: 'public', enum: ['public', 'private'] })
  @IsEnum(['public', 'private'])
  @IsOptional()
  accessType?: string;

  @ApiProperty({ example: 'post', required: false })
  @IsOptional()
  @IsString()
  relatedEntityType?: string;

  @ApiProperty({ example: 'uuid-of-post', required: false })
  @IsOptional()
  @IsUUID()
  relatedEntityId?: string;
}

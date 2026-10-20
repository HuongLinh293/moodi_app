import { IsString, IsArray, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendMessageDto {
  @ApiProperty({ example: 'Xin chào mọi người' })
  @IsString()
  @MaxLength(5000)
  content: string;

  @ApiProperty({ example: ['image-url-1'], required: false })
  @IsOptional()
  @IsArray()
  imageUrls?: string[];
}

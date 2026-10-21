import { IsString, IsArray, IsOptional, MaxLength, Matches, ArrayMaxSize } from 'class-validator';
import { SAFE_MEDIA_URL } from '../../common/media-url';
import { ApiProperty } from '@nestjs/swagger';

export class SendMessageDto {
  @ApiProperty({ example: 'Xin chào mọi người' })
  @IsString()
  @MaxLength(5000)
  content: string;

  @ApiProperty({ example: ['image-url-1'], required: false })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @Matches(SAFE_MEDIA_URL, { each: true, message: 'Ảnh phải là URL https hoặc file trong /api/storage' })
  imageUrls?: string[];
}

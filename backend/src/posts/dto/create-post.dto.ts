import { IsString, IsOptional, IsArray, MaxLength, Matches, ArrayMaxSize } from 'class-validator';
import { SAFE_MEDIA_URL } from '../../common/media-url';
import { ApiProperty } from '@nestjs/swagger';

export class CreatePostDto {
  @ApiProperty({ example: 'Hôm nay tôi cảm thấy rất tốt!' })
  @IsString()
  @MaxLength(5000)
  content: string;

  @ApiProperty({ example: ['image-id-1', 'image-id-2'], required: false })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @Matches(SAFE_MEDIA_URL, { each: true, message: 'Ảnh phải là URL https hoặc file trong /api/storage' })
  imageUrls?: string[];
}

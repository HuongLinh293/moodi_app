import { IsString, IsOptional, MaxLength, Matches } from 'class-validator';
import { SAFE_MEDIA_URL } from '../../common/media-url';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateGroupDto {
  @ApiProperty({ example: 'Tâm sự buổi tối', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  name?: string;

  @ApiProperty({ example: 'Nơi chia sẻ những điều trên trái tim', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @ApiProperty({ example: 'image-url', required: false })
  @IsOptional()
  @IsString()
  @Matches(SAFE_MEDIA_URL, { message: 'Ảnh phải là URL https hoặc file trong /api/storage' })
  image?: string;
}

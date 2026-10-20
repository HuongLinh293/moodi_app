import { IsString, IsOptional, IsArray, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreatePostDto {
  @ApiProperty({ example: 'Hôm nay tôi cảm thấy rất tốt!' })
  @IsString()
  @MaxLength(5000)
  content: string;

  @ApiProperty({ example: ['image-id-1', 'image-id-2'], required: false })
  @IsOptional()
  @IsArray()
  imageUrls?: string[];
}

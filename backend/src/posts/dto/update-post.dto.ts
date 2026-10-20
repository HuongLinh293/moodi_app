import { IsString, IsOptional, IsArray, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdatePostDto {
  @ApiProperty({ example: 'Hôm nay tôi cảm thấy tốt hơn!', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  content?: string;

  @ApiProperty({ example: ['image-id-1'], required: false })
  @IsOptional()
  @IsArray()
  imageUrls?: string[];
}

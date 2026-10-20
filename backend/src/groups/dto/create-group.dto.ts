import { IsString, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateGroupDto {
  @ApiProperty({ example: 'Tâm sự buổi tối' })
  @IsString()
  @MaxLength(255)
  name: string;

  @ApiProperty({ example: 'Nơi chia sẻ những điều trên trái tim', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @ApiProperty({ example: 'image-url', required: false })
  @IsOptional()
  @IsString()
  image?: string;
}

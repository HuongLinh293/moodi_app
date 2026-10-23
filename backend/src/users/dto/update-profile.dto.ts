import { IsString, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateProfileDto {
  @ApiProperty({ example: 'Alice Wonder', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;

  @ApiProperty({ example: 'Chia sẻ những khoảnh khắc tốt đẹp', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  bio?: string;
}

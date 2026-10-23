import {
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SaveEntryDto {
  @ApiProperty({ example: 'entry-1729500000000', required: false })
  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{1,160}$/)
  id?: string;

  // Client gửi kèm; server luôn dùng user trong JWT và từ chối nếu khác.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  userId?: string;

  @ApiProperty({ example: '2026-10-21T08:00:00.000Z' })
  @IsISO8601()
  timestamp: string;

  @ApiProperty({ example: 'calm' })
  @IsString()
  @MaxLength(40)
  emotionKey: string;

  @ApiProperty({ example: 3 })
  @IsInt()
  @Min(1)
  @Max(5)
  intensity: number;

  @ApiProperty({ example: 'other', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  trigger?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  situation?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  thought?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  response?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  exerciseId?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  exerciseDone?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  afterIntensity?: number | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  afterEmotionKey?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  usefulnessRating?: number | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  easeRating?: number | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @IsIn(['yes', 'maybe', 'no'])
  repeatPreference?: string | null;
}

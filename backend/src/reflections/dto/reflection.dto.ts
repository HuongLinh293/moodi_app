import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { EMOTIONS } from '../cbt-templates';

export class GenerateReflectionDto {
  @ApiProperty({ example: 'stressed', enum: EMOTIONS })
  @IsIn(EMOTIONS)
  emotionKey: string;

  @ApiProperty({ example: 3 })
  @IsInt()
  @Min(1)
  @Max(5)
  intensity: number;

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

  @ApiProperty({ required: false, description: 'Id nhật ký phía app' })
  @IsOptional()
  @IsString()
  @MaxLength(160)
  entryId?: string;
}

export class ReflectionFeedbackDto {
  @ApiProperty({ required: false })
  @IsString()
  @MaxLength(1000)
  feedback: string;

  @ApiProperty()
  @IsBoolean()
  helpful: boolean;
}

export class RecommendExerciseDto {
  @ApiProperty({ example: 'anxious', enum: EMOTIONS })
  @IsIn(EMOTIONS)
  emotionKey: string;

  @ApiProperty({ example: 4 })
  @IsInt()
  @Min(1)
  @Max(5)
  intensity: number;
}

export class SafetyCheckDto {
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
}

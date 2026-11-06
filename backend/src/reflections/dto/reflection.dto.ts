import { ArrayMaxSize, IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
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

export class ReflectionEditsDto {
  @IsOptional() @IsArray() @ArrayMaxSize(10) @IsString({ each: true }) @MaxLength(100, { each: true }) possibleEmotions?: string[];
  @IsOptional() @IsString() @MaxLength(1000) possibleTrigger?: string;
  @IsOptional() @IsString() @MaxLength(4000) intensifyingThought?: string;
  @IsOptional() @IsString() @MaxLength(4000) balancedThought?: string;
  @IsOptional() @IsString() @MaxLength(4000) reflectionQuestion?: string;
  @IsOptional() @IsString() @MaxLength(80) recommendedExercise?: string;
  @IsOptional() @IsString() @MaxLength(4000) recommendationReason?: string;
  @IsOptional() @IsString() @MaxLength(4000) microGoalPrompt?: string;
  @IsOptional() @IsBoolean() recommendationsDismissed?: boolean;
}

export class ReflectionFeedbackDto {
  @IsOptional() @ValidateNested() @Type(() => ReflectionEditsDto)
  edits?: ReflectionEditsDto;

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

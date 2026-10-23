import { IsBoolean, IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateGardenDto {
  // Client gửi kèm; server luôn dùng user trong JWT và từ chối nếu khác.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  userId?: string;

  @ApiProperty({ example: 'Lan' })
  @IsString()
  @MaxLength(200)
  userName: string;

  @ApiProperty({ example: 'Vườn sẻ chia', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  gardenName?: string;
}

export class JoinGardenDto {
  @ApiProperty({ example: 'MD-0123456789ABCDEF0123456789ABCDEF' })
  @IsString()
  @MaxLength(64)
  code: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  userId?: string;

  @ApiProperty({ example: 'Minh' })
  @IsString()
  @MaxLength(200)
  userName: string;
}

export class PlantEntryDto {
  @ApiProperty({ example: 'entry-1729500000000' })
  @Matches(/^[A-Za-z0-9_-]{1,160}$/)
  entryId: string;

  // Mặc định không chia sẻ nội dung ghi chép, chỉ cảm xúc và cường độ.
  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  includeCaption?: boolean;
}

export class InteractMomentDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  isWater: boolean;

  // Bỏ qua: server dùng tên thành viên đã lưu để không giả danh được.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  interactorName?: string;
}

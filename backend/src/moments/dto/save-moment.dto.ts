import { IsInt, IsISO8601, IsOptional, IsString, Matches, Max, Min } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SaveMomentDto {
  @ApiProperty({ example: 'garden-entry-1729500000000', required: false })
  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{1,160}$/)
  id?: string;

  // Client gửi kèm; server luôn dùng user trong JWT và từ chối nếu khác.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  userId?: string;

  @ApiProperty({ example: 'entry-1729500000000' })
  @Matches(/^[A-Za-z0-9_-]{1,160}$/)
  entryId: string;

  @ApiProperty({ example: '2026-10' })
  @Matches(/^\d{4}-\d{2}$/)
  monthKey: string;

  @ApiProperty({ example: 0 })
  @IsInt()
  @Min(0)
  @Max(1000)
  bedIndex: number;

  @ApiProperty({ example: 0 })
  @IsInt()
  @Min(0)
  @Max(1000)
  slotIndex: number;

  @ApiProperty({ example: '2026-10-21T08:00:00.000Z' })
  @IsISO8601()
  plantedAt: string;

  @ApiProperty({ example: 0, required: false })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  appearanceVariant?: number;
}

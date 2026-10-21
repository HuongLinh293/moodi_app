import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateAvatarDto {
  // Chỉ nhận id file đã tải lên qua /storage, không nhận URL tuỳ ý
  // (tránh javascript:/data: URL hoặc theo dõi qua ảnh bên ngoài).
  @ApiProperty({ example: 'uuid-of-storage-file' })
  @IsUUID()
  avatar: string;
}

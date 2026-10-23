import { ApiProperty } from '@nestjs/swagger';

export class StorageFileResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  filename: string;

  @ApiProperty()
  filePath: string;

  @ApiProperty()
  fileSize: number;

  @ApiProperty()
  mimeType: string;

  @ApiProperty()
  accessType: string;

  @ApiProperty()
  uploadedById: string;

  @ApiProperty()
  relatedEntityType: string;

  @ApiProperty()
  relatedEntityId: string;

  @ApiProperty()
  createdAt: Date;
}

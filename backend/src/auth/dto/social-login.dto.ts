import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class GoogleLoginDto {
  @ApiProperty({ description: 'ID token từ Google Sign-In' })
  @IsString()
  @MaxLength(4096)
  idToken: string;

  @ApiProperty({ required: false, description: 'Nonce gốc; SHA-256 của nó đã được gửi cho Google' })
  @IsOptional()
  @IsString()
  @MinLength(32)
  @MaxLength(128)
  rawNonce?: string;
}

export class AppleLoginDto {
  @ApiProperty({ description: 'identityToken từ Sign in with Apple' })
  @IsString()
  @MaxLength(4096)
  identityToken: string;

  @ApiProperty({ description: 'Nonce gốc; SHA-256 của nó đã được gửi cho Apple' })
  @IsString()
  @MinLength(32)
  @MaxLength(128)
  rawNonce: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;
}

import { Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { createHash, timingSafeEqual } from 'crypto';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';

export interface SocialIdentity {
  provider: 'google' | 'apple';
  subject: string;
  email?: string;
  emailVerified: boolean;
  name?: string;
}

const list = (value?: string) =>
  (value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

// Xác minh ID token bằng khoá công khai của nhà cung cấp (JWKS, có cache trong jose).
// Server không bao giờ tin email/sub do client tự khai.
@Injectable()
export class SocialVerifier {
  private googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
  private appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

  googleEnabled(): boolean {
    return list(process.env.GOOGLE_CLIENT_IDS).length > 0;
  }

  appleEnabled(): boolean {
    return list(process.env.APPLE_CLIENT_IDS).length > 0;
  }

  // Nonce không bắt buộc với Google (một số nền tảng không nhúng được), nhưng nếu
  // token có nonce hoặc client gửi rawNonce thì hai bên phải khớp.
  async verifyGoogle(idToken: string, rawNonce?: string): Promise<SocialIdentity> {
    const audience = list(process.env.GOOGLE_CLIENT_IDS);
    if (!audience.length) {
      throw new ServiceUnavailableException('Đăng nhập Google chưa được cấu hình');
    }
    const payload = await this.verify(idToken, this.googleKeys, {
      audience,
      issuer: ['https://accounts.google.com', 'accounts.google.com'],
    });
    if (rawNonce !== undefined || payload.nonce !== undefined) {
      this.assertNonce(payload, rawNonce ?? '', 'Google');
    }
    return {
      provider: 'google',
      subject: String(payload.sub),
      email: typeof payload.email === 'string' ? payload.email.toLowerCase() : undefined,
      emailVerified: payload.email_verified === true,
      name: typeof payload.name === 'string' ? payload.name : undefined,
    };
  }

  // rawNonce: client băm SHA-256 gửi cho Apple, còn bản gốc gửi cho server.
  // Token bị đánh cắp không dùng lại được vì kẻ tấn công không có rawNonce.
  async verifyApple(identityToken: string, rawNonce: string): Promise<SocialIdentity> {
    const audience = list(process.env.APPLE_CLIENT_IDS);
    if (!audience.length) {
      throw new ServiceUnavailableException('Đăng nhập Apple chưa được cấu hình');
    }
    const payload = await this.verify(identityToken, this.appleKeys, {
      audience,
      issuer: 'https://appleid.apple.com',
    });
    this.assertNonce(payload, rawNonce, 'Apple');
    // Apple trả email_verified dạng boolean hoặc chuỗi "true".
    const verified = payload.email_verified === true || payload.email_verified === 'true';
    return {
      provider: 'apple',
      subject: String(payload.sub),
      email: typeof payload.email === 'string' ? payload.email.toLowerCase() : undefined,
      emailVerified: verified,
    };
  }

  private assertNonce(payload: JWTPayload, rawNonce: string, provider: string) {
    const expected = createHash('sha256').update(rawNonce).digest('hex');
    const actual = typeof payload.nonce === 'string' ? payload.nonce : '';
    if (
      !rawNonce ||
      actual.length !== expected.length ||
      !timingSafeEqual(Buffer.from(actual), Buffer.from(expected))
    ) {
      throw new UnauthorizedException(`Phiên đăng nhập ${provider} không hợp lệ`);
    }
  }

  private async verify(
    token: string,
    keys: ReturnType<typeof createRemoteJWKSet>,
    options: { audience: string[]; issuer: string | string[] },
  ): Promise<JWTPayload> {
    try {
      const { payload } = await jwtVerify(token, keys, {
        ...options,
        algorithms: ['RS256'],
        maxTokenAge: '1h',
      });
      if (!payload.sub) throw new Error('missing sub');
      return payload;
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      throw new UnauthorizedException('Token đăng nhập không hợp lệ hoặc đã hết hạn');
    }
  }
}

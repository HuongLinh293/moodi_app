import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { createHash, randomBytes, timingSafeEqual } from 'crypto';
import { v4 as uuid } from 'uuid';
import { User } from '../users/entities/user.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { SocialIdentity, SocialVerifier } from './social-verifier';
import {
  jwtAccessSecret,
  jwtAccessTtl,
  jwtRefreshSecret,
  jwtRefreshTtl,
} from '../config/jwt.config';

// So sánh với hash giả khi email không tồn tại để thời gian phản hồi không
// tiết lộ email nào đã đăng ký.
const DUMMY_HASH = bcrypt.hashSync(randomBytes(16).toString('hex'), 10);
// bcrypt bỏ qua phần sau 72 byte; mật khẩu dài hơn sẽ "trùng" nhau.
const BCRYPT_MAX_BYTES = 72;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private jwtService: JwtService,
    private socialVerifier: SocialVerifier,
  ) {}

  async register(registerDto: RegisterDto): Promise<AuthResponseDto> {
    const { email, username, password, displayName } = registerDto;
    this.assertPasswordLength(password);

    // Check if user already exists
    const existingUser = await this.usersRepository.findOne({
      where: [{ email }, { username }],
    });

    if (existingUser) {
      throw new BadRequestException('Email hoặc username đã tồn tại');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = this.usersRepository.create({
      id: uuid(),
      email,
      username,
      password: hashedPassword,
      displayName: displayName || username,
    });

    await this.usersRepository.save(user);

    // Generate tokens
    return this.generateTokens(user);
  }

  async login(loginDto: LoginDto): Promise<AuthResponseDto> {
    const { email, password } = loginDto;

    // Find user
    const user = await this.usersRepository.findOne({ where: { email } });

    // Luôn chạy bcrypt.compare để email không tồn tại mất cùng thời gian.
    const isPasswordValid = await bcrypt.compare(
      password.slice(0, 200),
      user?.password ?? DUMMY_HASH,
    );

    if (!user || !isPasswordValid) {
      throw new UnauthorizedException('Email hoặc mật khẩu không đúng');
    }

    // Generate tokens
    return this.generateTokens(user);
  }

  async loginWithGoogle(idToken: string, rawNonce?: string): Promise<AuthResponseDto> {
    return this.loginWithIdentity(await this.socialVerifier.verifyGoogle(idToken, rawNonce));
  }

  async loginWithApple(
    identityToken: string,
    rawNonce: string,
    displayName?: string,
  ): Promise<AuthResponseDto> {
    const identity = await this.socialVerifier.verifyApple(identityToken, rawNonce);
    // Apple chỉ gửi tên ở lần đăng nhập đầu, qua app chứ không nằm trong token.
    return this.loginWithIdentity({ ...identity, name: displayName });
  }

  socialProviders(): { google: boolean; apple: boolean } {
    return {
      google: this.socialVerifier.googleEnabled(),
      apple: this.socialVerifier.appleEnabled(),
    };
  }

  async refreshToken(refreshToken: string): Promise<AuthResponseDto> {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: jwtRefreshSecret(),
      });

      const user = await this.usersRepository.findOne({ where: { id: payload.sub } });

      if (!user || payload.ver !== user.tokenVersion) {
        throw new UnauthorizedException('User không tồn tại');
      }

      // Chỉ refresh token phát hành gần nhất còn hiệu lực (xoay vòng mỗi lần refresh).
      if (!this.matchesStoredHash(refreshToken, user.refreshTokenHash)) {
        throw new UnauthorizedException('Refresh token không hợp lệ');
      }

      return this.generateTokens(user);
    } catch (error) {
      throw new UnauthorizedException('Refresh token không hợp lệ');
    }
  }

  // Tăng tokenVersion để vô hiệu cả access token đang còn hạn.
  async logout(userId: string): Promise<void> {
    await this.usersRepository.update(userId, { refreshTokenHash: null });
    await this.usersRepository.increment({ id: userId }, 'tokenVersion', 1);
  }

  private async loginWithIdentity(identity: SocialIdentity): Promise<AuthResponseDto> {
    const subjectColumn = identity.provider === 'google' ? 'googleSub' : 'appleSub';

    let user = await this.usersRepository.findOne({
      where: { [subjectColumn]: identity.subject },
    });

    // Chỉ liên kết với tài khoản sẵn có khi nhà cung cấp xác nhận email,
    // nếu không ai đó có thể chiếm tài khoản bằng email chưa xác minh.
    if (!user && identity.email && identity.emailVerified) {
      user = await this.usersRepository.findOne({ where: { email: identity.email } });
      if (user) {
        user[subjectColumn] = identity.subject;
        await this.usersRepository.save(user);
      }
    }

    if (!user) {
      const suffix = randomBytes(5).toString('hex');
      const email =
        identity.email && identity.emailVerified
          ? identity.email
          : `${identity.provider}-${createHash('sha256').update(identity.subject).digest('hex').slice(0, 24)}@users.noreply.moodi`;
      user = this.usersRepository.create({
        id: uuid(),
        email,
        username: `${identity.provider[0]}_${suffix}`,
        // Tài khoản mạng xã hội không có mật khẩu dùng được.
        password: await bcrypt.hash(randomBytes(32).toString('hex'), 10),
        displayName: identity.name?.trim().slice(0, 100) || 'Bạn mới',
        isVerified: identity.emailVerified,
        [subjectColumn]: identity.subject,
      });
      await this.usersRepository.save(user);
    }

    return this.generateTokens(user);
  }

  private assertPasswordLength(password: string) {
    if (Buffer.byteLength(password, 'utf8') > BCRYPT_MAX_BYTES) {
      throw new BadRequestException('Mật khẩu tối đa 72 byte');
    }
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private matchesStoredHash(token: string, storedHash?: string | null): boolean {
    if (!storedHash) return false;
    const actual = Buffer.from(this.hashToken(token), 'hex');
    const expected = Buffer.from(storedHash, 'hex');
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  }

  private async generateTokens(user: User): Promise<AuthResponseDto> {
    const payload = { sub: user.id, ver: user.tokenVersion };

    const accessToken = this.jwtService.sign(payload, {
      secret: jwtAccessSecret(),
      expiresIn: jwtAccessTtl(),
    });

    // jti ngẫu nhiên: hai lần refresh trong cùng một giây vẫn ra token khác nhau.
    const refreshToken = this.jwtService.sign(
      { ...payload, jti: randomBytes(16).toString('hex') },
      {
        secret: jwtRefreshSecret(),
        expiresIn: jwtRefreshTtl(),
      },
    );

    const expiresAt = Math.floor(Date.now() / 1000) + jwtAccessTtl();

    // bcrypt chỉ băm 72 byte đầu, trùng nhau giữa các JWT của cùng user.
    await this.usersRepository.update(user.id, {
      refreshTokenHash: this.hashToken(refreshToken),
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.displayName,
        avatar: user.avatar,
      },
      accessToken,
      refreshToken,
      expiresAt,
    };
  }
}

import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { v4 as uuid } from 'uuid';
import { User } from '../users/entities/user.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private jwtService: JwtService,
  ) {}

  async register(registerDto: RegisterDto): Promise<AuthResponseDto> {
    const { email, username, password, displayName } = registerDto;

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

    if (!user) {
      throw new UnauthorizedException('Email hoặc mật khẩu không đúng');
    }

    // Compare password
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Email hoặc mật khẩu không đúng');
    }

    // Generate tokens
    return this.generateTokens(user);
  }

  async refreshToken(refreshToken: string): Promise<AuthResponseDto> {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET,
      });

      const user = await this.usersRepository.findOne({ where: { id: payload.sub } });

      if (!user) {
        throw new UnauthorizedException('User không tồn tại');
      }

      return this.generateTokens(user);
    } catch (error) {
      throw new UnauthorizedException('Refresh token không hợp lệ');
    }
  }

  private async generateTokens(user: User): Promise<AuthResponseDto> {
    const payload = { sub: user.id, email: user.email };

    const accessToken = this.jwtService.sign(payload, {
      secret: process.env.JWT_SECRET,
      expiresIn: parseInt(process.env.JWT_EXPIRATION || '3600'),
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: process.env.JWT_REFRESH_SECRET,
      expiresIn: parseInt(process.env.JWT_REFRESH_EXPIRATION || '604800'),
    });

    const expiresAt = Math.floor(Date.now() / 1000) + (parseInt(process.env.JWT_EXPIRATION || '3600'));

    // Store refresh token hash (optional)
    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    user.refreshTokenHash = refreshTokenHash;
    await this.usersRepository.save(user);

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

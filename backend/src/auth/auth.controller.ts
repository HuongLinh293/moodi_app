import { Controller, Get, Post, Body, HttpCode, HttpStatus, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { AppleLoginDto, GoogleLoginDto } from './dto/social-login.dto';
import { JwtGuard } from './guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

// Giới hạn chặt hơn mức toàn cục để chống dò mật khẩu/brute-force.
const AUTH_LIMIT = { default: { limit: 10, ttl: 60_000 } };

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  @Throttle(AUTH_LIMIT)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Đăng ký tài khoản' })
  @ApiResponse({ status: 201, type: AuthResponseDto })
  async register(@Body() registerDto: RegisterDto): Promise<AuthResponseDto> {
    return this.authService.register(registerDto);
  }

  @Post('login')
  @Throttle(AUTH_LIMIT)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng nhập' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  async login(@Body() loginDto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(loginDto);
  }

  @Get('providers')
  @ApiOperation({ summary: 'Các phương thức đăng nhập mạng xã hội đang bật' })
  providers() {
    return this.authService.socialProviders();
  }

  @Post('google')
  @Throttle(AUTH_LIMIT)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng nhập bằng Google ID token' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  async google(@Body() dto: GoogleLoginDto): Promise<AuthResponseDto> {
    return this.authService.loginWithGoogle(dto.idToken, dto.rawNonce);
  }

  @Post('apple')
  @Throttle(AUTH_LIMIT)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng nhập bằng Apple identity token' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  async apple(@Body() dto: AppleLoginDto): Promise<AuthResponseDto> {
    return this.authService.loginWithApple(dto.identityToken, dto.rawNonce, dto.displayName);
  }

  @Post('refresh-token')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Làm mới access token' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  async refreshToken(@Body() refreshTokenDto: RefreshTokenDto): Promise<AuthResponseDto> {
    return this.authService.refreshToken(refreshTokenDto.refreshToken);
  }

  @Post('logout')
  @UseGuards(JwtGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Đăng xuất, thu hồi refresh token và access token' })
  async logout(@CurrentUser() user: User): Promise<void> {
    await this.authService.logout(user.id);
  }
}

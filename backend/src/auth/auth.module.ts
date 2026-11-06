import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PasswordReset } from './password-reset.entity';
import { PasswordResetService } from './password-reset.service';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { SocialVerifier } from './social-verifier';
import { User } from '../users/entities/user.entity';
import { jwtAccessSecret, jwtAccessTtl } from '../config/jwt.config';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, PasswordReset]),
    PassportModule,
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: jwtAccessSecret(),
        signOptions: { expiresIn: jwtAccessTtl() },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [PasswordResetService, AuthService, JwtStrategy, SocialVerifier],
  exports: [AuthService],
})
export class AuthModule {}

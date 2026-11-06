import { BadRequestException, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, LessThan, ILike } from 'typeorm';
import { createHmac, randomInt, randomUUID, timingSafeEqual } from 'crypto';
import * as bcrypt from 'bcrypt';
import { IsEmail, IsString, IsUUID, Matches, MaxLength, MinLength } from 'class-validator';
import { PasswordReset } from './password-reset.entity';
import { User } from '../users/entities/user.entity';
import { jwtRefreshSecret } from '../config/jwt.config';

export class ForgotPasswordDto { @IsEmail() @MaxLength(255) email: string; }
export class ResetPasswordDto {
  @IsUUID() requestId: string;
  @IsString() @Matches(/^\d{6}$/) code: string;
  @IsString() @MinLength(8) @MaxLength(72) password: string;
}

@Injectable()
export class PasswordResetService {
  private readonly logger = new Logger(PasswordResetService.name);
  constructor(@InjectRepository(PasswordReset) private resets: Repository<PasswordReset>, @InjectRepository(User) private users: Repository<User>, @InjectDataSource() private db: DataSource) {}
  private hash(id: string, code: string) { return createHmac('sha256', jwtRefreshSecret()).update(`${id}:${code}`).digest('hex'); }

  async request(dto: ForgotPasswordDto) {
    if (!process.env.RESEND_API_KEY || !process.env.PASSWORD_RESET_FROM) {
      throw new ServiceUnavailableException('Khôi phục mật khẩu chưa được bật. Hãy thử phương thức Google/Apple đã liên kết hoặc liên hệ hỗ trợ.');
    }
    const user = await this.users.findOne({ where: { email: ILike(dto.email.trim()) } });
    // Both existing and unknown emails receive an opaque request ID and exactly
    // the same response. Never return a code or log it, even in development.
    const id = randomUUID();
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    await this.resets.delete({ expiresAt: LessThan(new Date()) });
    // Keep codes already sent: deleting them here would let anyone invalidate a
    // victim's code by requesting a new one. A small cap bounds email spam.
    const active = user ? await this.resets.count({ where: { userId: user.id } }) : 0;
    const send = !!user && active < 5;
    await this.resets.save({ id, userId: send ? user!.id : null, codeHash: this.hash(id, code), expiresAt: new Date(Date.now() + 10 * 60_000), attempts: 0 });
    // Do not await delivery: response time must not depend on whether the account exists.
    if (send) void this.deliver(id, user!.email, code);
    return { requestId: id, message: 'Nếu email có tài khoản Moodi, mã khôi phục sẽ được gửi. Hãy kiểm tra cả thư rác.' };
  }

  private async deliver(id: string, email: string, code: string) {
    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST', signal: AbortSignal.timeout(10_000),
        headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: process.env.PASSWORD_RESET_FROM, to: [email], subject: 'Mã khôi phục mật khẩu Moodi', text: `Mã khôi phục của bạn: ${code}\nMã có hiệu lực 10 phút và chỉ dùng một lần. Nếu không yêu cầu khôi phục, bạn có thể bỏ qua email này.` }),
      });
      if (!response.ok) throw new Error('delivery failed');
    } catch (_) {
      this.logger.error('Password recovery email could not be delivered. Check mail provider configuration.');
      await this.resets.delete({ id }).catch(() => undefined);
    }
  }

  async reset(dto: ResetPasswordDto) {
    if (Buffer.byteLength(dto.password, 'utf8') > 72) throw new BadRequestException('Mật khẩu tối đa 72 byte.');
    const password = await bcrypt.hash(dto.password, 10);
    const accepted = await this.db.transaction(async manager => {
      const row = await manager.findOne(PasswordReset, { where: { id: dto.requestId }, lock: { mode: 'pessimistic_write' } });
      if (!row || row.attempts >= 5 || row.expiresAt.getTime() <= Date.now()) return false;
      row.attempts++;
      const actual = Buffer.from(this.hash(row.id, dto.code), 'hex');
      const expected = Buffer.from(row.codeHash, 'hex');
      if (!row.userId || actual.length !== expected.length || !timingSafeEqual(actual, expected)) { await manager.save(PasswordReset, row); return false; }
      await manager.update(User, { id: row.userId }, { password, refreshTokenHash: null, tokenVersion: () => '"tokenVersion" + 1' });
      await manager.delete(PasswordReset, { userId: row.userId });
      return true;
    });
    if (!accepted) throw new BadRequestException('Mã không đúng, đã hết hạn hoặc đã dùng. Hãy yêu cầu mã mới.');
  }
}

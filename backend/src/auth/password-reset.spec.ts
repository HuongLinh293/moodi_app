import { Logger } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PasswordResetService } from './password-reset.service';
import { PasswordReset } from './password-reset.entity';
import { User } from '../users/entities/user.entity';

describe('password recovery', () => {
  const originalEnv = { ...process.env };
  let service: PasswordResetService;
  let rows: Map<string, any>;
  let sentCode: string;
  let updates: any[];
  let hasAccount: boolean;
  beforeEach(() => {
    process.env.RESEND_API_KEY = 'test-only'; process.env.PASSWORD_RESET_FROM = 'test@example.invalid'; process.env.JWT_REFRESH_SECRET = 'a-test-only-secret';
    rows = new Map(); updates = []; hasAccount = true; sentCode = '';
    const remove = async (where: any) => { for (const [id, row] of rows) { if (where.id === id || where.userId === row.userId || (where.expiresAt && row.expiresAt < new Date())) rows.delete(id); } };
    const save = async (row: any) => { rows.set(row.id, { ...row }); return row; };
    const count = async ({ where }: any) => [...rows.values()].filter(r => r.userId === where.userId).length;
    const resets: any = { delete: remove, save, count };
    const users: any = { findOne: async () => hasAccount ? { id: 'user', email: 'test@example.invalid' } : null };
    const manager: any = {
      findOne: async (_: any, options: any) => rows.get(options.where.id) ?? null,
      save: async (type: any, row: any) => { expect(type).toBe(PasswordReset); return save(row); },
      delete: async (type: any, where: any) => { expect(type).toBe(PasswordReset); return remove(where); },
      update: async (type: any, where: any, change: any) => { expect(type).toBe(User); updates.push({ where, change }); },
    };
    service = new PasswordResetService(resets, users, { transaction: async (run: any) => run(manager) } as any);
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    jest.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
      const body = JSON.parse(init!.body as string);
      sentCode = body.text.match(/\b\d{6}\b/)[0];
      return new Response('{}', { status: 200 });
    });
  });
  afterEach(() => { process.env = { ...originalEnv }; jest.restoreAllMocks(); });

  it('sends a code but never exposes or stores the plaintext code', async () => {
    const result = await service.request({ email: 'test@example.invalid' });
    expect(sentCode).toMatch(/^\d{6}$/);
    expect(JSON.stringify(result)).not.toContain(sentCode);
    expect(rows.get(result.requestId).codeHash).not.toBe(sentCode);
  });
  it('uses a code once, hashes the new password and revokes old sessions', async () => {
    const result = await service.request({ email: 'test@example.invalid' });
    await service.reset({ requestId: result.requestId, code: sentCode, password: 'New-password-123' });
    expect(await bcrypt.compare('New-password-123', updates[0].change.password)).toBe(true);
    expect(updates[0].change.refreshTokenHash).toBeNull();
    expect(updates[0].change.tokenVersion()).toContain('+ 1');
    await expect(service.reset({ requestId: result.requestId, code: sentCode, password: 'New-password-123' })).rejects.toThrow();
  });
  it('limits attempts even when later supplied with the correct code', async () => {
    const result = await service.request({ email: 'test@example.invalid' });
    const invalidCode = sentCode === '000000' ? '000001' : '000000';
    for (let i = 0; i < 5; i++) await expect(service.reset({ requestId: result.requestId, code: invalidCode, password: 'New-password-123' })).rejects.toThrow();
    await expect(service.reset({ requestId: result.requestId, code: sentCode, password: 'New-password-123' })).rejects.toThrow();
    expect(updates).toHaveLength(0);
  });
  it('rejects expired codes', async () => {
    const result = await service.request({ email: 'test@example.invalid' });
    rows.get(result.requestId).expiresAt = new Date(Date.now() - 1);
    await expect(service.reset({ requestId: result.requestId, code: sentCode, password: 'New-password-123' })).rejects.toThrow();
    expect(updates).toHaveLength(0);
  });
  it('does not disclose whether an email exists', async () => {
    const found = await service.request({ email: 'test@example.invalid' });
    hasAccount = false;
    const unknown = await service.request({ email: 'unknown@example.invalid' });
    expect(found.message).toBe(unknown.message);
    expect(Object.keys(found)).toEqual(Object.keys(unknown));
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });
  it('a new request does not invalidate a code already sent', async () => {
    const first = await service.request({ email: 'test@example.invalid' });
    const firstCode = sentCode;
    await service.request({ email: 'test@example.invalid' });
    await service.reset({ requestId: first.requestId, code: firstCode, password: 'New-password-123' });
    expect(updates).toHaveLength(1);
  });
  it('answers without waiting for email delivery', async () => {
    (global.fetch as jest.Mock).mockImplementation(() => new Promise(() => undefined));
    await expect(service.request({ email: 'test@example.invalid' })).resolves.toHaveProperty('requestId');
  });
  it('reports unavailable recovery when mail is not configured', async () => {
    delete process.env.RESEND_API_KEY;
    await expect(service.request({ email: 'test@example.invalid' })).rejects.toThrow('chưa được bật');
    expect(global.fetch).not.toHaveBeenCalled();
  });
});

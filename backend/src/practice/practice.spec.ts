import { PracticeService } from './practice.module';
import { User } from '../users/entities/user.entity';

describe('practice records', () => {
  const user = { id: 'owner' } as User;
  it('allows an independent session without inventing a mood', async () => {
    const save = jest.fn(async row => row);
    const service = new PracticeService({ save } as any, { exist: jest.fn() } as any);
    const record = await service.save(user, 'session-1', { exerciseId: 'grounding', timestamp: new Date().toISOString(), note: 'Chưa rõ cảm xúc' });
    expect(record.userId).toBe('owner');
    expect(record.beforeEmotionKey).toBeUndefined();
    expect(record.afterIntensity).toBeUndefined();
  });
  it('rejects another account or a deleted source entry', async () => {
    const save = jest.fn();
    const entries = { exist: jest.fn(async () => false) };
    const service = new PracticeService({ save } as any, entries as any);
    await expect(service.save(user, 'session-1', { exerciseId: 'grounding', timestamp: new Date().toISOString(), sourceEntryId: 'someone-elses-entry' })).rejects.toThrow();
    expect(save).not.toHaveBeenCalled();
    expect(entries.exist).toHaveBeenCalledWith({ where: { userId: 'owner', id: 'someone-elses-entry' } });
  });
  it('uses account-scoped stable ids so another practice does not overwrite the first', async () => {
    const rows = new Map();
    const service = new PracticeService({ save: async (row: any) => { rows.set(`${row.userId}:${row.id}`, row); return row; } } as any, {} as any);
    const dto = { exerciseId: 'grounding', timestamp: new Date().toISOString() };
    await service.save(user, 'session-1', dto);
    await service.save(user, 'session-2', dto);
    await service.save(user, 'session-1', { ...dto, afterIntensity: 5 });
    expect(rows.size).toBe(2);
    expect(rows.get('owner:session-1').afterIntensity).toBe(5);
    expect(rows.get('owner:session-2').afterIntensity).toBeUndefined();
  });
});

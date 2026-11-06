import { EntriesService } from './entries.service';
import { JournalEntry } from './entities/journal-entry.entity';
import { AiReflection } from '../reflections/entities/ai-reflection.entity';
import { GardenMoment } from '../moments/entities/garden-moment.entity';
import { PracticeRecord } from '../practice/practice.entity';
import { User } from '../users/entities/user.entity';

describe('journal derivative lifecycle', () => {
  const user = { id: 'owner' } as User;
  let manager: any, repo: any, service: EntriesService;
  beforeEach(() => {
    manager = { find: jest.fn(async () => []), findOne: jest.fn(async () => null), delete: jest.fn(async () => undefined), save: jest.fn(async (_type, value) => value) };
    repo = { create: (value: any) => value, findOne: jest.fn(async () => ({ id: 'entry', userId: 'owner' })) };
    service = new EntriesService({ transaction: async (run: any) => run(manager) } as any, repo);
  });
  it('deletes related private data only for the owning entry', async () => {
    await service.delete(user, 'entry');
    expect(manager.delete).toHaveBeenCalledWith(AiReflection, { userId: 'owner', entryId: 'entry' });
    expect(manager.delete).toHaveBeenCalledWith(PracticeRecord, { userId: 'owner', sourceEntryId: 'entry' });
    expect(manager.delete).toHaveBeenCalledWith(GardenMoment, { userId: 'owner', entryId: 'entry' });
    expect(manager.delete).toHaveBeenCalledWith(JournalEntry, { userId: 'owner', id: 'entry' });
  });
  it('clears account derivatives together with all journal entries', async () => {
    await service.deleteAll(user);
    for (const type of [AiReflection, PracticeRecord, GardenMoment, JournalEntry]) expect(manager.delete).toHaveBeenCalledWith(type, { userId: 'owner' });
  });
  it('invalidates a reflection when its original thought changes', async () => {
    manager.findOne.mockResolvedValue({ emotionKey: 'sad', intensity: 3, situation: 'Cũ', thought: 'Suy nghĩ cũ' });
    await service.save(user, { timestamp: new Date().toISOString(), emotionKey: 'sad', intensity: 3, situation: 'Cũ', thought: 'Suy nghĩ mới' }, 'entry');
    expect(manager.delete).toHaveBeenCalledWith(AiReflection, { userId: 'owner', entryId: 'entry' });
  });
});

import { ReflectionsService } from './reflections.service';
import { User } from '../users/entities/user.entity';

describe('reflection lifecycle', () => {
  const user = { id: 'owner' } as User;
  const dto = { entryId: 'entry-1', emotionKey: 'sad', intensity: 3, situation: 'Trượt bài kiểm tra', thought: 'Mình có thể học lại' };
  let existing: any;
  let journal: any;
  let service: ReflectionsService;
  let repo: any;
  beforeEach(() => {
    existing = null;
    journal = { ...dto, id: dto.entryId, userId: user.id };
    repo = {
      findOne: jest.fn(async () => existing), create: (row: any) => row,
      save: jest.fn(async (row: any) => { existing = { id: 'reflection', ...row }; return existing; }),
    };
    service = new ReflectionsService(repo, { findOne: async () => journal } as any);
    jest.spyOn(service as any, 'fromGemini').mockResolvedValue(null);
  });
  afterEach(() => jest.restoreAllMocks());

  it('reuses a reflection only for the exact same input', async () => {
    const first = await service.generate(user, dto);
    const same = await service.generate(user, dto);
    expect(repo.save).toHaveBeenCalledTimes(1);
    expect(same).toEqual(first);
    expect(first).not.toHaveProperty('_inputHash');
    journal.thought = 'Một suy nghĩ khác';
    await service.generate(user, { ...dto, thought: journal.thought });
    expect(repo.save).toHaveBeenCalledTimes(2);
    expect(existing.result.intensifyingThought).toBe(journal.thought);
  });

  it('does not create a derivative for a deleted journal', async () => {
    journal = null;
    await expect(service.generate(user, dto)).rejects.toThrow('Ghi chép');
    expect(repo.save).not.toHaveBeenCalled();
  });

  it('rejects a late result when the journal was changed during generation', async () => {
    jest.spyOn(service as any, 'fromGemini').mockImplementation(async () => {
      journal.thought = 'Nội dung mới hơn';
      return null;
    });
    await expect(service.generate(user, dto)).rejects.toThrow('thay đổi');
    expect(repo.save).not.toHaveBeenCalled();
  });

  it('preserves safety metadata while accepting feedback', async () => {
    existing = { id: 'safety', source: 'safety', result: { safetyFlag: true, balancedThought: 'Safety copy' } };
    await service.feedback(user, 'safety', { feedback: 'needs_edit', helpful: false, edits: { balancedThought: 'Changed text' } });
    expect(existing.result.safetyFlag).toBe(true);
    expect(existing.result.balancedThought).toBe('Safety copy');
    expect(existing.feedback).toBe('needs_edit');
  });

  it('persists user edits without exposing another account reflection', async () => {
    await expect(service.feedback(user, 'missing', { feedback: 'accurate', helpful: true })).rejects.toThrow();
    await service.generate(user, dto);
    await service.feedback(user, 'reflection', { feedback: 'needs_edit', helpful: false, edits: { balancedThought: 'Lời của tôi', recommendationsDismissed: true } });
    expect(existing.result.balancedThought).toBe('Lời của tôi');
    expect(existing.result.recommendationsDismissed).toBe(true);
    expect(repo.findOne).toHaveBeenLastCalledWith({ where: { id: 'reflection', userId: 'owner' } });
  });
});

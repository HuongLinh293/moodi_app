import { Logger } from '@nestjs/common';
import { ReflectionsService } from './reflections.service';
import { User } from '../users/entities/user.entity';

const aiJson = {
  possibleEmotions: ['Lo âu'],
  possibleTrigger: 'Kỳ thi sắp tới',
  intensifyingThought: 'Mình sẽ trượt',
  reflectionQuestion: 'Bằng chứng nào cho thấy điều đó chắc chắn xảy ra?',
  balancedThought: 'Mình đã ôn tập và có thể làm từng câu một.',
  recommendedExercise: 'thought_reframing',
  recommendationReason: 'Tách sự thật khỏi nỗi sợ.',
  microGoalPrompt: 'Ôn lại một chương trong 5 phút.',
};

const ok = () =>
  new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(aiJson) }] } }] }),
    { status: 200 },
  );
const fail = (status: number) => new Response('{}', { status });

describe('ReflectionsService Gemini fallback', () => {
  let service: ReflectionsService;
  let fetchMock: jest.SpyInstance;
  const saved: any[] = [];
  const env = { ...process.env };

  beforeEach(() => {
    saved.length = 0;
    process.env.GEMINI_API_KEY = 'test-key';
    delete process.env.REFLECTION_AI_DISABLED;
    delete process.env.GEMINI_MODEL;
    delete process.env.GEMINI_FALLBACK_MODEL;
    const repo: any = {
      findOne: async () => null,
      create: (value: any) => value,
      save: async (value: any) => {
        saved.push(value);
        return { id: 'r1', createdAt: new Date(), ...value };
      },
    };
    service = new ReflectionsService(repo, {} as any);
    service.retryDelayMs = 0;
    fetchMock = jest.spyOn(global, 'fetch');
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    process.env = { ...env };
  });

  const generate = () =>
    service.generate({ id: 'u1' } as User, {
      emotionKey: 'anxious',
      intensity: 3,
      situation: 'Sắp thi',
      thought: 'Mình sẽ trượt',
    });
  const models = () =>
    fetchMock.mock.calls.map(([url]) => String(url).match(/models\/(.+):generate/)![1]);

  it('uses the primary model when it answers', async () => {
    fetchMock.mockResolvedValueOnce(ok());
    const result = await generate();
    expect(result.source).toBe('ai');
    expect(models()).toEqual(['gemini-3.5-flash']);
  });

  it('retries the primary model once when it is overloaded', async () => {
    fetchMock.mockResolvedValueOnce(fail(503)).mockResolvedValueOnce(ok());
    const result = await generate();
    expect(result.source).toBe('ai');
    expect(models()).toEqual(['gemini-3.5-flash', 'gemini-3.5-flash']);
  });

  it('falls back to the second model after two overloads', async () => {
    fetchMock
      .mockResolvedValueOnce(fail(503))
      .mockResolvedValueOnce(fail(429))
      .mockResolvedValueOnce(ok());
    const result = await generate();
    expect(result.source).toBe('ai');
    expect(result.reflectionQuestion).toBe(aiJson.reflectionQuestion);
    expect(models()).toEqual(['gemini-3.5-flash', 'gemini-3.5-flash', 'gemini-3.5-flash-lite']);
  });

  it('goes straight to the fallback model when the primary is missing', async () => {
    fetchMock.mockResolvedValueOnce(fail(404)).mockResolvedValueOnce(ok());
    const result = await generate();
    expect(result.source).toBe('ai');
    expect(models()).toEqual(['gemini-3.5-flash', 'gemini-3.5-flash-lite']);
  });

  it('stops on a key error and uses the template', async () => {
    fetchMock.mockResolvedValue(fail(403));
    const result = await generate();
    expect(result.source).toBe('template');
    expect(models()).toEqual(['gemini-3.5-flash']);
  });

  it('uses the template when every attempt fails', async () => {
    fetchMock.mockResolvedValue(fail(503));
    const result = await generate();
    expect(result.source).toBe('template');
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it('never sends crisis content to the provider', async () => {
    const result = await service.generate({ id: 'u1' } as User, {
      emotionKey: 'sad',
      intensity: 5,
      thought: 'Mình muốn chết',
    });
    expect(result.source).toBe('safety');
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { Between, DataSource, FindOptionsWhere, MoreThanOrEqual, LessThanOrEqual, Repository } from 'typeorm';
import { v4 as uuid } from 'uuid';
import { JournalEntry } from './entities/journal-entry.entity';
import { SaveEntryDto } from './dto/save-entry.dto';
import { User } from '../users/entities/user.entity';
import {
  SharedMoment,
  SharedMomentCare,
} from '../shared-gardens/entities/shared-garden.entity';

@Injectable()
export class EntriesService {
  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
    @InjectRepository(JournalEntry)
    private entriesRepository: Repository<JournalEntry>,
  ) {}

  async findAll(user: User): Promise<any[]> {
    const entries = await this.entriesRepository.find({
      where: { userId: user.id },
      order: { timestamp: 'DESC' },
    });
    return entries.map((entry) => this.toEntryResponse(entry));
  }

  async search(
    user: User,
    emotionKey?: string,
    startDate?: string,
    endDate?: string,
  ): Promise<any[]> {
    const where: FindOptionsWhere<JournalEntry> = { userId: user.id };
    if (emotionKey) where.emotionKey = emotionKey;
    const start = this.parseDate(startDate);
    const end = this.parseDate(endDate);
    if (start && end) where.timestamp = Between(start, end);
    else if (start) where.timestamp = MoreThanOrEqual(start);
    else if (end) where.timestamp = LessThanOrEqual(end);

    const entries = await this.entriesRepository.find({
      where,
      order: { timestamp: 'DESC' },
    });
    return entries.map((entry) => this.toEntryResponse(entry));
  }

  async findForDate(user: User, date: string): Promise<any[]> {
    const start = this.parseDate(`${date}T00:00:00.000Z`);
    if (!start) return [];
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1);
    return this.search(user, undefined, start.toISOString(), end.toISOString());
  }

  async findById(user: User, id: string): Promise<any> {
    const entry = await this.entriesRepository.findOne({
      where: { userId: user.id, id },
    });

    if (!entry) {
      throw new NotFoundException('Ghi chép không tồn tại');
    }

    return this.toEntryResponse(entry);
  }

  async save(user: User, dto: SaveEntryDto, id?: string): Promise<any> {
    if (dto.userId && dto.userId !== user.id) {
      throw new ForbiddenException('Không thể ghi dữ liệu cho tài khoản khác');
    }

    const { userId: _ignored, id: _bodyId, ...fields } = dto;
    const entry = this.entriesRepository.create({
      ...fields,
      id: id ?? dto.id ?? `entry-${uuid()}`,
      userId: user.id,
      timestamp: new Date(dto.timestamp),
    });

    // Upsert theo (userId, id) để PUT lặp lại khi đồng bộ không tạo bản trùng.
    await this.entriesRepository.save(entry);
    return this.findById(user, entry.id);
  }

  async delete(user: User, id: string): Promise<void> {
    // Gỡ luôn bông hoa đã chia sẻ để nội dung không còn trong vườn chung.
    await this.dataSource.transaction(async (manager) => {
      const shared = await manager.find(SharedMoment, {
        where: { authorId: user.id, entryId: id },
      });
      for (const moment of shared) {
        await manager.delete(SharedMomentCare, {
          gardenId: moment.gardenId,
          momentId: moment.id,
        });
        await manager.delete(SharedMoment, { gardenId: moment.gardenId, id: moment.id });
      }
      await manager.delete(JournalEntry, { userId: user.id, id });
    });
  }

  async deleteAll(user: User): Promise<void> {
    await this.entriesRepository.delete({ userId: user.id });
  }

  private parseDate(value?: string): Date | null {
    if (!value) return null;
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  private toEntryResponse(entry: JournalEntry): any {
    return {
      id: entry.id,
      timestamp: entry.timestamp,
      emotionKey: entry.emotionKey,
      intensity: entry.intensity,
      trigger: entry.trigger,
      situation: entry.situation,
      thought: entry.thought,
      response: entry.response,
      exerciseId: entry.exerciseId,
      exerciseDone: entry.exerciseDone,
      afterIntensity: entry.afterIntensity,
      afterEmotionKey: entry.afterEmotionKey,
      usefulnessRating: entry.usefulnessRating,
      easeRating: entry.easeRating,
      repeatPreference: entry.repeatPreference,
      updatedAt: entry.updatedAt,
    };
  }
}

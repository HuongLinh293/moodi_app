import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { randomBytes } from 'crypto';
import {
  SharedGarden,
  SharedGardenMember,
  SharedMoment,
  SharedMomentCare,
} from './entities/shared-garden.entity';
import { CreateGardenDto, JoinGardenDto, PlantEntryDto } from './dto/shared-garden.dto';
import { JournalEntry } from '../entries/entities/journal-entry.entity';
import { User } from '../users/entities/user.entity';

const MAX_MEMBERS = 2;
const SLOTS_PER_BED = 20;
const INVITE_CODE = /^MD-[A-F0-9]{32}$/;

@Injectable()
export class SharedGardensService {
  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
    @InjectRepository(SharedGarden)
    private gardensRepository: Repository<SharedGarden>,
    @InjectRepository(SharedGardenMember)
    private membersRepository: Repository<SharedGardenMember>,
    @InjectRepository(SharedMoment)
    private momentsRepository: Repository<SharedMoment>,
  ) {}

  async create(user: User, dto: CreateGardenDto): Promise<any> {
    this.assertSameUser(user, dto.userId);

    const existing = await this.membersRepository.findOne({ where: { userId: user.id } });
    if (existing) return this.findGarden(existing.gardenId);

    const gardenId = await this.dataSource.transaction(async (manager) => {
      const garden = await manager.save(
        manager.create(SharedGarden, {
          code: this.newCode(),
          name: dto.gardenName?.trim() || 'Vườn sẻ chia',
        }),
      );
      await manager.save(
        manager.create(SharedGardenMember, {
          gardenId: garden.id,
          userId: user.id,
          displayName: this.cleanName(dto.userName),
        }),
      );
      return garden.id;
    });

    return this.findGarden(gardenId);
  }

  async join(user: User, dto: JoinGardenDto): Promise<any> {
    this.assertSameUser(user, dto.userId);

    const code = dto.code.trim().toUpperCase();
    if (!INVITE_CODE.test(code)) {
      throw new BadRequestException('Mã mời đã cũ hoặc không hợp lệ. Hãy nhờ bạn gửi mã mới.');
    }

    const gardenId = await this.dataSource.transaction(async (manager) => {
      const garden = await manager.findOne(SharedGarden, {
        where: { code },
        lock: { mode: 'pessimistic_write' },
      });
      if (!garden) {
        throw new NotFoundException('Không tìm thấy mã mời hoặc mã đã hết hiệu lực.');
      }

      const membership = await manager.findOne(SharedGardenMember, {
        where: { userId: user.id },
      });
      if (membership) {
        if (membership.gardenId !== garden.id) {
          throw new ConflictException('Hãy rời vườn hiện tại trước khi vào vườn khác.');
        }
        return garden.id;
      }

      const memberCount = await manager.count(SharedGardenMember, {
        where: { gardenId: garden.id },
      });
      if (memberCount >= MAX_MEMBERS) {
        throw new ConflictException('Vườn đã đủ thành viên.');
      }

      await manager.save(
        manager.create(SharedGardenMember, {
          gardenId: garden.id,
          userId: user.id,
          displayName: this.cleanName(dto.userName),
        }),
      );
      return garden.id;
    });

    return this.findGarden(gardenId);
  }

  async findUserGarden(user: User): Promise<any> {
    const membership = await this.membersRepository.findOne({ where: { userId: user.id } });
    // Client nhận diện "chưa có vườn" qua thiếu trường id.
    if (!membership) return {};
    return this.findGarden(membership.gardenId);
  }

  async findById(user: User, gardenId: string): Promise<any> {
    await this.requireMember(this.dataSource.manager, gardenId, user.id);
    return this.findGarden(gardenId);
  }

  async findMoments(user: User, gardenId: string): Promise<any[]> {
    await this.requireMember(this.dataSource.manager, gardenId, user.id);
    const moments = await this.momentsRepository.find({
      where: { gardenId },
      order: { plantedAt: 'ASC' },
    });
    return moments.map((moment) => this.toMomentResponse(moment));
  }

  async plant(user: User, gardenId: string, dto: PlantEntryDto): Promise<any> {
    return this.dataSource.transaction(async (manager) => {
      // Khoá vườn để cấp nextSlot tuần tự khi hai người trồng cùng lúc.
      const garden = await manager.findOne(SharedGarden, {
        where: { id: gardenId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!garden) throw new NotFoundException('Vườn không còn tồn tại.');
      const member = await this.requireMember(manager, gardenId, user.id);

      const momentId = `${user.id}_${dto.entryId}`;
      const existing = await manager.findOne(SharedMoment, { where: { gardenId, id: momentId } });
      if (existing) return this.toMomentResponse(existing);

      // Chỉ trồng được ghi chép của chính mình đã đồng bộ lên server.
      const entry = await manager.findOne(JournalEntry, {
        where: { userId: user.id, id: dto.entryId },
      });
      if (!entry) {
        throw new ConflictException('Ghi chép chưa được đồng bộ. Hãy thử lại.');
      }

      const position = garden.nextSlot;
      const situation = entry.situation.trim();
      const plantedAt = entry.timestamp;
      const moment = await manager.save(
        manager.create(SharedMoment, {
          gardenId,
          id: momentId,
          authorId: user.id,
          authorName: member.displayName,
          entryId: entry.id,
          emotionKey: entry.emotionKey,
          intensity: entry.intensity,
          caption: dto.includeCaption ? situation || entry.thought.trim() : '',
          bedIndex: Math.floor(position / SLOTS_PER_BED),
          slotIndex: position % SLOTS_PER_BED,
          monthKey: plantedAt.toISOString().slice(0, 7),
          plantedAt,
          waterCount: 0,
          sunCount: 0,
          lastInteraction: null,
        }),
      );
      garden.nextSlot = position + 1;
      await manager.save(garden);

      return this.toMomentResponse(moment);
    });
  }

  async removeMoment(user: User, gardenId: string, momentId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      await this.requireMember(manager, gardenId, user.id);
      const moment = await manager.findOne(SharedMoment, { where: { gardenId, id: momentId } });
      if (!moment) throw new NotFoundException('Khoảnh khắc không còn tồn tại.');
      if (moment.authorId !== user.id) {
        throw new ForbiddenException('Chỉ người trồng mới gỡ được bông hoa này.');
      }
      await manager.delete(SharedMomentCare, { gardenId, momentId });
      await manager.delete(SharedMoment, { gardenId, id: momentId });
    });
  }

  async removeMyMoments(user: User, gardenId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      await this.requireMember(manager, gardenId, user.id);
      const mine = await manager.find(SharedMoment, {
        where: { gardenId, authorId: user.id },
        select: { id: true },
      });
      for (const moment of mine) {
        await manager.delete(SharedMomentCare, { gardenId, momentId: moment.id });
      }
      await manager.delete(SharedMoment, { gardenId, authorId: user.id });
    });
  }

  async leave(user: User, gardenId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const garden = await manager.findOne(SharedGarden, {
        where: { id: gardenId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!garden) throw new NotFoundException('Vườn không còn tồn tại.');
      await this.requireMember(manager, gardenId, user.id);

      await manager.delete(SharedGardenMember, { gardenId, userId: user.id });
      await manager.delete(SharedMomentCare, { gardenId, userId: user.id });

      const remaining = await manager.count(SharedGardenMember, { where: { gardenId } });
      if (remaining === 0) {
        await manager.delete(SharedGarden, { id: gardenId });
        return;
      }
      // Người rời không được dùng lại mã cũ để quay lại.
      garden.code = this.newCode();
      await manager.save(garden);
    });
  }

  async refreshInvite(user: User, gardenId: string): Promise<{ code: string }> {
    await this.requireMember(this.dataSource.manager, gardenId, user.id);
    const code = this.newCode();
    await this.gardensRepository.update({ id: gardenId }, { code });
    return { code };
  }

  async interact(
    user: User,
    gardenId: string,
    momentId: string,
    isWater: boolean,
  ): Promise<any> {
    return this.dataSource.transaction(async (manager) => {
      const member = await this.requireMember(manager, gardenId, user.id);
      const moment = await manager.findOne(SharedMoment, {
        where: { gardenId, id: momentId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!moment) throw new NotFoundException('Khoảnh khắc không còn tồn tại.');

      const care =
        (await manager.findOne(SharedMomentCare, {
          where: { gardenId, momentId, userId: user.id },
        })) ??
        manager.create(SharedMomentCare, {
          gardenId,
          momentId,
          userId: user.id,
          water: false,
          sun: false,
        });

      if (isWater ? care.water : care.sun) return this.toMomentResponse(moment);

      if (isWater) {
        care.water = true;
        moment.waterCount += 1;
        moment.lastInteraction = `${member.displayName} vừa tưới nước 💧`;
      } else {
        care.sun = true;
        moment.sunCount += 1;
        moment.lastInteraction = `${member.displayName} vừa gửi tia nắng ấm ☀️`;
      }
      await manager.save(care);
      await manager.save(moment);

      return this.toMomentResponse(moment);
    });
  }

  private async requireMember(
    manager: EntityManager,
    gardenId: string,
    userId: string,
  ): Promise<SharedGardenMember> {
    const member = await manager.findOne(SharedGardenMember, { where: { gardenId, userId } });
    if (!member) {
      throw new ForbiddenException('Bạn không phải thành viên của vườn này.');
    }
    return member;
  }

  private async findGarden(gardenId: string): Promise<any> {
    const garden = await this.gardensRepository.findOne({
      where: { id: gardenId },
      relations: ['members'],
    });
    if (!garden) throw new NotFoundException('Vườn không còn tồn tại.');

    const members = [...garden.members].sort(
      (a, b) => a.joinedAt.getTime() - b.joinedAt.getTime(),
    );
    return {
      id: garden.id,
      code: garden.code,
      name: garden.name,
      members: members.map((member) => member.userId),
      memberNames: Object.fromEntries(
        members.map((member) => [member.userId, member.displayName]),
      ),
      createdAt: garden.createdAt,
    };
  }

  private assertSameUser(user: User, userId?: string): void {
    if (userId && userId !== user.id) {
      throw new ForbiddenException('Phiên đăng nhập đã thay đổi.');
    }
  }

  private newCode(): string {
    return `MD-${randomBytes(16).toString('hex').toUpperCase()}`;
  }

  private cleanName(name: string): string {
    const trimmed = name.trim();
    return trimmed ? trimmed.slice(0, 80) : 'Bạn đồng hành';
  }

  private toMomentResponse(moment: SharedMoment): any {
    return {
      id: moment.id,
      gardenId: moment.gardenId,
      authorId: moment.authorId,
      authorName: moment.authorName,
      emotionKey: moment.emotionKey,
      intensity: moment.intensity,
      caption: moment.caption,
      bedIndex: moment.bedIndex,
      slotIndex: moment.slotIndex,
      monthKey: moment.monthKey,
      plantedAt: moment.plantedAt,
      waterCount: moment.waterCount,
      sunCount: moment.sunCount,
      lastInteraction: moment.lastInteraction,
    };
  }
}

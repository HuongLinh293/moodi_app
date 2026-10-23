import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, Repository } from 'typeorm';
import { v4 as uuid } from 'uuid';
import { GardenMoment } from './entities/garden-moment.entity';
import { SaveMomentDto } from './dto/save-moment.dto';
import { User } from '../users/entities/user.entity';

@Injectable()
export class MomentsService {
  constructor(
    @InjectRepository(GardenMoment)
    private momentsRepository: Repository<GardenMoment>,
  ) {}

  async findAll(user: User, filter: { monthKey?: string; bedIndex?: number } = {}): Promise<any[]> {
    const where: FindOptionsWhere<GardenMoment> = { userId: user.id };
    if (filter.monthKey) where.monthKey = filter.monthKey;
    if (filter.bedIndex !== undefined) where.bedIndex = filter.bedIndex;

    const moments = await this.momentsRepository.find({
      where,
      order: { plantedAt: 'ASC' },
    });
    return moments.map((moment) => this.toMomentResponse(moment));
  }

  async findById(user: User, id: string): Promise<any> {
    const moment = await this.momentsRepository.findOne({
      where: { userId: user.id, id },
    });

    if (!moment) {
      throw new NotFoundException('Khoảnh khắc không tồn tại');
    }

    return this.toMomentResponse(moment);
  }

  async save(user: User, dto: SaveMomentDto, id?: string): Promise<any> {
    if (dto.userId && dto.userId !== user.id) {
      throw new ForbiddenException('Không thể ghi dữ liệu cho tài khoản khác');
    }

    const { userId: _ignored, id: _bodyId, ...fields } = dto;
    const moment = this.momentsRepository.create({
      ...fields,
      id: id ?? dto.id ?? `garden-${uuid()}`,
      userId: user.id,
      plantedAt: new Date(dto.plantedAt),
    });

    await this.momentsRepository.save(moment);
    return this.findById(user, moment.id);
  }

  async delete(user: User, id: string): Promise<void> {
    await this.momentsRepository.delete({ userId: user.id, id });
  }

  async deleteAll(user: User): Promise<void> {
    await this.momentsRepository.delete({ userId: user.id });
  }

  private toMomentResponse(moment: GardenMoment): any {
    return {
      id: moment.id,
      entryId: moment.entryId,
      monthKey: moment.monthKey,
      bedIndex: moment.bedIndex,
      slotIndex: moment.slotIndex,
      plantedAt: moment.plantedAt,
      appearanceVariant: moment.appearanceVariant,
      updatedAt: moment.updatedAt,
    };
  }
}

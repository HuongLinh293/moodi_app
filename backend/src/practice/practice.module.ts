import { Body, Controller, Get, Module, Param, Put, UseGuards, Injectable, ForbiddenException } from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { IsDateString, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ClientIdPipe } from '../common/pipes/client-id.pipe';
import { User } from '../users/entities/user.entity';
import { JournalEntry } from '../entries/entities/journal-entry.entity';
import { EMOTIONS } from '../reflections/cbt-templates';
import { PracticeRecord } from './practice.entity';

export class SavePracticeDto {
  @IsOptional() @IsString() @MaxLength(160) id?: string;
  @IsString() @MaxLength(80) exerciseId: string;
  @IsDateString() timestamp: string;
  @IsOptional() @IsString() @MaxLength(160) sourceEntryId?: string;
  @IsOptional() @IsString() @MaxLength(12000) note?: string;
  @IsOptional() @IsIn(EMOTIONS) beforeEmotionKey?: string;
  @IsOptional() @IsInt() @Min(1) @Max(5) beforeIntensity?: number;
  @IsOptional() @IsIn(EMOTIONS) afterEmotionKey?: string;
  @IsOptional() @IsInt() @Min(1) @Max(5) afterIntensity?: number;
  @IsOptional() @IsInt() @Min(1) @Max(5) usefulnessRating?: number;
  @IsOptional() @IsInt() @Min(1) @Max(5) easeRating?: number;
  @IsOptional() @IsIn(['yes', 'no', 'maybe']) repeatPreference?: string;
}

@Injectable()
export class PracticeService {
  constructor(@InjectRepository(PracticeRecord) private records: Repository<PracticeRecord>, @InjectRepository(JournalEntry) private entries: Repository<JournalEntry>) {}
  all(user: User) { return this.records.find({ where: { userId: user.id }, order: { timestamp: 'DESC' } }); }
  async save(user: User, id: string, dto: SavePracticeDto) {
    if (dto.sourceEntryId && !await this.entries.exist({ where: { userId: user.id, id: dto.sourceEntryId } })) {
      throw new ForbiddenException('Ghi chép nguồn không còn tồn tại trong tài khoản của bạn.');
    }
    return this.records.save({ ...dto, id, userId: user.id, timestamp: new Date(dto.timestamp) });
  }
}

@UseGuards(JwtGuard)
@Controller('practice')
class PracticeController {
  constructor(private service: PracticeService) {}
  @Get() all(@CurrentUser() user: User) { return this.service.all(user); }
  @Put(':id') save(@CurrentUser() user: User, @Param('id', ClientIdPipe) id: string, @Body() dto: SavePracticeDto) { return this.service.save(user, id, dto); }
}

@Module({ imports: [TypeOrmModule.forFeature([PracticeRecord, JournalEntry])], controllers: [PracticeController], providers: [PracticeService] })
export class PracticeModule {}

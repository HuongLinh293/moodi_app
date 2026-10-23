import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  SharedGarden,
  SharedGardenMember,
  SharedMoment,
  SharedMomentCare,
} from './entities/shared-garden.entity';
import { JournalEntry } from '../entries/entities/journal-entry.entity';
import { SharedGardensService } from './shared-gardens.service';
import { SharedGardensController } from './shared-gardens.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      SharedGarden,
      SharedGardenMember,
      SharedMoment,
      SharedMomentCare,
      JournalEntry,
    ]),
  ],
  controllers: [SharedGardensController],
  providers: [SharedGardensService],
  exports: [TypeOrmModule],
})
export class SharedGardensModule {}

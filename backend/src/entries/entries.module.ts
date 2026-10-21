import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JournalEntry } from './entities/journal-entry.entity';
import { EntriesService } from './entries.service';
import { EntriesController } from './entries.controller';

@Module({
  imports: [TypeOrmModule.forFeature([JournalEntry])],
  controllers: [EntriesController],
  providers: [EntriesService],
  exports: [TypeOrmModule],
})
export class EntriesModule {}

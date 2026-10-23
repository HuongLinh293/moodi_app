import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AiReflection } from './entities/ai-reflection.entity';
import { JournalEntry } from '../entries/entities/journal-entry.entity';
import { ReflectionsService } from './reflections.service';
import { ReflectionsController } from './reflections.controller';

@Module({
  imports: [TypeOrmModule.forFeature([AiReflection, JournalEntry])],
  controllers: [ReflectionsController],
  providers: [ReflectionsService],
})
export class ReflectionsModule {}

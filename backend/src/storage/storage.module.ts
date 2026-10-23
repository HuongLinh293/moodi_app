import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StorageFile } from './entities/storage-file.entity';
import { User } from '../users/entities/user.entity';
import { StorageService } from './storage.service';
import { StorageController } from './storage.controller';

@Module({
  imports: [TypeOrmModule.forFeature([StorageFile, User])],
  controllers: [StorageController],
  providers: [StorageService],
  exports: [TypeOrmModule],
})
export class StorageModule {}

import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { PracticeRecord } from '../practice/practice.entity';
import { PasswordReset } from '../auth/password-reset.entity';
import { User } from '../users/entities/user.entity';
import { StorageFile } from '../storage/entities/storage-file.entity';
import { Notification } from '../notifications/entities/notification.entity';
import { JournalEntry } from '../entries/entities/journal-entry.entity';
import { GardenMoment } from '../moments/entities/garden-moment.entity';
import {
  SharedGarden,
  SharedGardenMember,
  SharedMoment,
  SharedMomentCare,
} from '../shared-gardens/entities/shared-garden.entity';
import { AiReflection } from '../reflections/entities/ai-reflection.entity';
import { COMMUNITY_ENTITIES } from '../community/community.entities';

export const databaseConfig = (): TypeOrmModuleOptions => ({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'moodi_db',
  entities: [
    User,
    StorageFile,
    Notification,
    JournalEntry,
    GardenMoment,
    SharedGarden,
    SharedGardenMember,
    SharedMoment,
    SharedMomentCare,
    AiReflection,
    PracticeRecord,
    PasswordReset,
    ...COMMUNITY_ENTITIES,
  ],
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV === 'development',
  migrations: ['dist/database/migrations/*.js'],
  migrationsTableName: 'migrations',
  migrationsRun: true,
});

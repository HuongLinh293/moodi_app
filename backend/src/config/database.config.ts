import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { User } from '../users/entities/user.entity';
import { Post } from '../posts/entities/post.entity';
import { PostLike } from '../posts/entities/post-like.entity';
import { Friend } from '../friends/entities/friend.entity';
import { FriendRequest } from '../friends/entities/friend-request.entity';
import { Group } from '../groups/entities/group.entity';
import { GroupMember } from '../groups/entities/group-member.entity';
import { GroupInvite } from '../groups/entities/group-invite.entity';
import { Conversation } from '../chat/entities/conversation.entity';
import { ConversationParticipant } from '../chat/entities/conversation-participant.entity';
import { Message } from '../chat/entities/message.entity';
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
    Post,
    PostLike,
    Friend,
    FriendRequest,
    Group,
    GroupMember,
    GroupInvite,
    Conversation,
    ConversationParticipant,
    Message,
    StorageFile,
    Notification,
    JournalEntry,
    GardenMoment,
    SharedGarden,
    SharedGardenMember,
    SharedMoment,
    SharedMomentCare,
    AiReflection,
    ...COMMUNITY_ENTITIES,
  ],
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV === 'development',
  migrations: ['dist/database/migrations/*.js'],
  migrationsTableName: 'migrations',
  migrationsRun: true,
});

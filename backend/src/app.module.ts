import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { HttpThrottlerGuard } from './common/http-throttler.guard';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { PostsModule } from './posts/posts.module';
import { GroupsModule } from './groups/groups.module';
import { FriendsModule } from './friends/friends.module';
import { ChatModule } from './chat/chat.module';
import { StorageModule } from './storage/storage.module';
import { NotificationsModule } from './notifications/notifications.module';
import { EntriesModule } from './entries/entries.module';
import { MomentsModule } from './moments/moments.module';
import { SharedGardensModule } from './shared-gardens/shared-gardens.module';
import { ReflectionsModule } from './reflections/reflections.module';
import { CommunityModule } from './community/community.module';
import { databaseConfig } from './config/database.config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    TypeOrmModule.forRoot(databaseConfig()),
    // Giới hạn chung theo IP; các route nhạy cảm đặt mức chặt hơn bằng @Throttle.
    ThrottlerModule.forRoot([
      { ttl: 60_000, limit: parseInt(process.env.THROTTLE_LIMIT || '300', 10) },
    ]),
    AuthModule,
    UsersModule,
    PostsModule,
    GroupsModule,
    FriendsModule,
    ChatModule,
    StorageModule,
    NotificationsModule,
    EntriesModule,
    MomentsModule,
    SharedGardensModule,
    ReflectionsModule,
    CommunityModule,
  ],
  controllers: [],
  providers: [{ provide: APP_GUARD, useClass: HttpThrottlerGuard }],
})
export class AppModule {}

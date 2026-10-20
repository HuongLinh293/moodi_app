import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { PostsModule } from './posts/posts.module';
import { GroupsModule } from './groups/groups.module';
import { FriendsModule } from './friends/friends.module';
import { ChatModule } from './chat/chat.module';
import { StorageModule } from './storage/storage.module';
import { NotificationsModule } from './notifications/notifications.module';
import { databaseConfig } from './config/database.config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    TypeOrmModule.forRoot(databaseConfig()),
    AuthModule,
    UsersModule,
    PostsModule,
    GroupsModule,
    FriendsModule,
    ChatModule,
    StorageModule,
    NotificationsModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}

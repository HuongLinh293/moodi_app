import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateInitialSchema1700000000000 implements MigrationInterface {
  name = 'CreateInitialSchema1700000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    `);

    // Users table
    await queryRunner.query(`
      CREATE TABLE "users" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "email" VARCHAR NOT NULL UNIQUE,
        "username" VARCHAR NOT NULL UNIQUE,
        "displayName" VARCHAR NOT NULL,
        "password" VARCHAR NOT NULL,
        "bio" TEXT,
        "avatar" VARCHAR,
        "isVerified" BOOLEAN NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id")
      );
    `);

    // Posts table
    await queryRunner.query(`
      CREATE TABLE "posts" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "authorId" UUID NOT NULL,
        "content" TEXT NOT NULL,
        "imageUrls" TEXT,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("authorId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Post likes table
    await queryRunner.query(`
      CREATE TABLE "post_likes" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "postId" UUID NOT NULL,
        "userId" UUID NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        UNIQUE ("postId", "userId"),
        FOREIGN KEY ("postId") REFERENCES "posts"("id") ON DELETE CASCADE,
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Friends table
    await queryRunner.query(`
      CREATE TABLE "friends" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "userId" UUID NOT NULL,
        "friendId" UUID NOT NULL,
        "status" VARCHAR NOT NULL DEFAULT 'accepted',
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        UNIQUE ("userId", "friendId"),
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE,
        FOREIGN KEY ("friendId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Friend requests table
    await queryRunner.query(`
      CREATE TABLE "friend_requests" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "senderId" UUID NOT NULL,
        "recipientId" UUID NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("senderId") REFERENCES "users"("id") ON DELETE CASCADE,
        FOREIGN KEY ("recipientId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Groups table
    await queryRunner.query(`
      CREATE TABLE "groups" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "name" VARCHAR(255) NOT NULL,
        "description" TEXT,
        "image" VARCHAR(500),
        "createdById" UUID,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL
      );
    `);

    // Group members table
    await queryRunner.query(`
      CREATE TABLE "group_members" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "groupId" UUID NOT NULL,
        "userId" UUID NOT NULL,
        "role" VARCHAR NOT NULL DEFAULT 'member',
        "joinedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        UNIQUE ("groupId", "userId"),
        FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE,
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Group invites table
    await queryRunner.query(`
      CREATE TABLE "group_invites" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "groupId" UUID NOT NULL,
        "userId" UUID NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE,
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Conversations table
    await queryRunner.query(`
      CREATE TABLE "conversations" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "type" VARCHAR NOT NULL,
        "name" VARCHAR,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id")
      );
    `);

    // Conversation participants table
    await queryRunner.query(`
      CREATE TABLE "conversation_participants" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "conversationId" UUID NOT NULL,
        "userId" UUID NOT NULL,
        "joinedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        UNIQUE ("conversationId", "userId"),
        FOREIGN KEY ("conversationId") REFERENCES "conversations"("id") ON DELETE CASCADE,
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Messages table
    await queryRunner.query(`
      CREATE TABLE "messages" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "conversationId" UUID NOT NULL,
        "senderId" UUID NOT NULL,
        "content" TEXT NOT NULL,
        "imageUrls" TEXT,
        "isEdited" BOOLEAN NOT NULL DEFAULT false,
        "editedAt" TIMESTAMP,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("conversationId") REFERENCES "conversations"("id") ON DELETE CASCADE,
        FOREIGN KEY ("senderId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Storage files table
    await queryRunner.query(`
      CREATE TABLE "storage_files" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "uploadedById" UUID NOT NULL,
        "filename" VARCHAR(255) NOT NULL,
        "filePath" VARCHAR(500) NOT NULL,
        "fileSize" INTEGER NOT NULL,
        "mimeType" VARCHAR(50),
        "accessType" VARCHAR NOT NULL DEFAULT 'private',
        "relatedEntityType" VARCHAR(50),
        "relatedEntityId" UUID,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("uploadedById") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Notifications table
    await queryRunner.query(`
      CREATE TABLE "notifications" (
        "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
        "userId" UUID NOT NULL,
        "type" VARCHAR NOT NULL,
        "title" VARCHAR NOT NULL,
        "message" TEXT,
        "data" JSONB,
        "isRead" BOOLEAN NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ("id"),
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    // Create indexes
    await queryRunner.query(`CREATE INDEX "IDX_posts_authorId" ON "posts"("authorId");`);
    await queryRunner.query(`CREATE INDEX "IDX_posts_createdAt" ON "posts"("createdAt");`);
    await queryRunner.query(`CREATE INDEX "IDX_friends_userId" ON "friends"("userId");`);
    await queryRunner.query(`CREATE INDEX "IDX_friends_friendId" ON "friends"("friendId");`);
    await queryRunner.query(`CREATE INDEX "IDX_groups_createdById" ON "groups"("createdById");`);
    await queryRunner.query(`CREATE INDEX "IDX_groupMembers_groupId" ON "group_members"("groupId");`);
    await queryRunner.query(`CREATE INDEX "IDX_groupMembers_userId" ON "group_members"("userId");`);
    await queryRunner.query(`CREATE INDEX "IDX_messages_conversationId" ON "messages"("conversationId");`);
    await queryRunner.query(`CREATE INDEX "IDX_messages_senderId" ON "messages"("senderId");`);
    await queryRunner.query(`CREATE INDEX "IDX_storageFiles_uploadedById" ON "storage_files"("uploadedById");`);
    await queryRunner.query(`CREATE INDEX "IDX_notifications_userId" ON "notifications"("userId");`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop all tables in reverse order
    await queryRunner.query(`DROP TABLE IF EXISTS "notifications";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "storage_files";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "messages";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "conversation_participants";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "conversations";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "group_invites";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "group_members";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "groups";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "friend_requests";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "friends";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "post_likes";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "posts";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "users";`);
  }
}

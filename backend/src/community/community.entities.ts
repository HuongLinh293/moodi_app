import { Entity, PrimaryColumn, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

// Port từ các collection Firestore của functions/community.js. Mảng thành viên
// được giữ dạng text[] để logic phân quyền giữ nguyên như bản gốc.
// Mọi truy cập đều đi qua CommunityService; không có route CRUD trực tiếp.

const ms = { type: 'timestamptz' as const, precision: 3 };

@Entity('community_profiles')
export class CommunityProfile {
  @PrimaryColumn('uuid')
  uid: string;

  @Column({ type: 'varchar', length: 40 })
  name: string;

  @Column({ type: 'varchar', length: 160, default: '' })
  bio: string;

  @Column({ type: 'varchar', length: 12, unique: true })
  handle: string;

  @Column({ type: 'boolean', default: false })
  suspended: boolean;

  @Column(ms)
  createdAt: Date;
}

@Entity('community_groups')
export class CommunityGroup {
  @PrimaryColumn({ type: 'varchar', length: 128 })
  id: string;

  @Column({ type: 'varchar', length: 60 })
  name: string;

  @Column({ type: 'varchar', length: 240, default: '' })
  description: string;

  @Column('uuid')
  owner: string;

  @Index()
  @Column('text', { array: true, default: '{}' })
  members: string[];

  @Column('text', { array: true, default: '{}' })
  invited: string[];

  @Column({ type: 'boolean', default: false })
  closed: boolean;

  @Column(ms)
  createdAt: Date;
}

@Entity('community_posts')
@Index(['space', 'createdAt'])
export class CommunityPost {
  @PrimaryColumn({ type: 'varchar', length: 128 })
  space: string;

  @PrimaryColumn({ type: 'varchar', length: 128 })
  id: string;

  @Column('uuid')
  author: string;

  @Column({ type: 'varchar', length: 40 })
  authorName: string;

  @Column({ type: 'text', default: '' })
  text: string;

  @Column({ type: 'varchar', length: 30, default: '' })
  mood: string;

  @Column({ type: 'varchar', length: 60, default: '' })
  intent: string;

  @Column({ type: 'varchar', length: 300, default: '' })
  imagePath: string;

  @Column(ms)
  createdAt: Date;

  @Column({ type: 'boolean', default: false })
  deleted: boolean;

  @Column({ type: 'boolean', default: true })
  ready: boolean;

  @Column({ type: 'boolean', default: true })
  commentsOpen: boolean;

  @Column({ type: 'int', default: 0 })
  likes: number;
}

@Entity('community_reactions')
export class CommunityReaction {
  @PrimaryColumn({ type: 'varchar', length: 128 })
  space: string;

  @PrimaryColumn({ type: 'varchar', length: 128 })
  postId: string;

  @PrimaryColumn('uuid')
  uid: string;

  @Column(ms)
  createdAt: Date;
}

@Entity('community_comments')
@Index(['space', 'postId', 'createdAt'])
export class CommunityComment {
  @PrimaryColumn({ type: 'varchar', length: 128 })
  space: string;

  @PrimaryColumn({ type: 'varchar', length: 128 })
  postId: string;

  @PrimaryColumn({ type: 'varchar', length: 128 })
  id: string;

  @Column('uuid')
  author: string;

  @Column({ type: 'varchar', length: 40 })
  authorName: string;

  @Column({ type: 'text', default: '' })
  text: string;

  @Column(ms)
  createdAt: Date;

  @Column({ type: 'boolean', default: false })
  deleted: boolean;
}

@Entity('community_connections')
export class CommunityConnection {
  // sha256 của cặp uid đã sắp xếp: một quan hệ duy nhất cho mỗi cặp.
  @PrimaryColumn({ type: 'varchar', length: 64 })
  id: string;

  @Index()
  @Column('text', { array: true })
  members: string[];

  @Column({ type: 'varchar', length: 64, default: '' })
  requestedBy: string;

  @Column({ type: 'varchar', length: 20, default: 'none' })
  status: string;

  @Column('text', { array: true, default: '{}' })
  blockedBy: string[];

  @Column({ type: 'boolean', default: false })
  hasMessages: boolean;

  @Column({ type: 'varchar', length: 64, nullable: true })
  lastSender: string | null;

  @Column({ ...ms, nullable: true })
  lastMessageAt: Date | null;
}

@Entity('community_messages')
@Index(['connectionId', 'createdAt'])
export class CommunityMessage {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  connectionId: string;

  @PrimaryColumn({ type: 'varchar', length: 128 })
  id: string;

  @Column('uuid')
  author: string;

  @Column({ type: 'text', default: '' })
  text: string;

  @Column({ type: 'varchar', length: 300, default: '' })
  imagePath: string;

  @Column(ms)
  createdAt: Date;

  @Column({ type: 'boolean', default: false })
  deleted: boolean;

  @Column({ type: 'boolean', default: true })
  ready: boolean;
}

@Entity('community_reads')
export class CommunityRead {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  connectionId: string;

  @PrimaryColumn('uuid')
  uid: string;

  @Column(ms)
  at: Date;
}

@Entity('community_reports')
@Index(['createdAt'])
export class CommunityReport {
  @PrimaryColumn({ type: 'varchar', length: 128 })
  id: string;

  @Column('uuid')
  reporter: string;

  @Column('uuid')
  target: string;

  @Column({ type: 'varchar', length: 400 })
  path: string;

  @Column({ type: 'text', default: '' })
  evidence: string;

  @Column({ type: 'varchar', length: 300, default: '' })
  imagePath: string;

  @Column({ type: 'varchar', length: 500 })
  reason: string;

  @Column({ type: 'varchar', length: 20, default: 'open' })
  status: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  resolution: string | null;

  @Column({ type: 'uuid', nullable: true })
  moderator: string | null;

  @Column({ ...ms, nullable: true })
  resolvedAt: Date | null;

  @Column(ms)
  createdAt: Date;
}

// Nhật ký kiểm duyệt: mọi lần xem báo cáo/ảnh và mọi quyết định đều được ghi lại.
@Entity('community_audit')
export class CommunityAudit {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  moderator: string;

  @Column({ type: 'varchar', length: 30 })
  kind: string;

  @Column({ type: 'varchar', length: 128, nullable: true })
  reportId: string | null;

  @Column(ms)
  createdAt: Date;
}

// Biên nhận idempotency: gửi lại cùng requestId trả kết quả cũ, không ghi lặp.
@Entity('community_operations')
export class CommunityOperation {
  @PrimaryColumn('uuid')
  uid: string;

  @PrimaryColumn({ type: 'varchar', length: 128 })
  requestId: string;

  @Column({ type: 'varchar', length: 64 })
  fingerprint: string;

  @Column({ type: 'jsonb' })
  result: Record<string, unknown>;

  @Column(ms)
  createdAt: Date;
}

@Entity('community_limits')
export class CommunityLimit {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  key: string;

  @Column({ type: 'bigint' })
  start: string;

  @Column({ type: 'int' })
  count: number;
}

// Ảnh đã qua sharp (JPEG ≤ 900KB). Chỉ đọc được qua action 'image'/'reportImage'
// sau khi kiểm tra quyền, không có URL công khai.
@Entity('community_media')
export class CommunityMedia {
  @PrimaryColumn({ type: 'varchar', length: 300 })
  path: string;

  @Column({ type: 'bytea' })
  bytes: Buffer;
}

export const COMMUNITY_ENTITIES = [
  CommunityProfile,
  CommunityGroup,
  CommunityPost,
  CommunityReaction,
  CommunityComment,
  CommunityConnection,
  CommunityMessage,
  CommunityRead,
  CommunityReport,
  CommunityAudit,
  CommunityOperation,
  CommunityLimit,
  CommunityMedia,
];

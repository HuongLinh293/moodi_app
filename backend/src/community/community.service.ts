import { HttpException, Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityManager, EntityTarget, In, ObjectLiteral, SelectQueryBuilder } from 'typeorm';
import { createHash, randomBytes } from 'crypto';
import sharp from 'sharp';
import {
  CommunityAudit,
  CommunityComment,
  CommunityConnection,
  CommunityGroup,
  CommunityLimit,
  CommunityMedia,
  CommunityMessage,
  CommunityOperation,
  CommunityPost,
  CommunityProfile,
  CommunityReaction,
  CommunityRead,
  CommunityReport,
} from './community.entities';
import { User } from '../users/entities/user.entity';
import { CRISIS_KEYWORDS } from '../reflections/cbt-templates';

// Port từ functions/community.js (Firebase callable) sang Postgres.
// Giữ nguyên hợp đồng action/payload để UI Flutter không phải đổi.

type Json = Record<string, any>;
type Cursor = { seconds: number; nanoseconds: number; id: string };
interface Relation {
  members: string[];
  requestedBy: string;
  status: string;
  blockedBy: string[];
  hasMessages: boolean;
  lastSender?: string | null;
  lastMessageAt?: Date | null;
}

const STATUS: Record<string, number> = {
  'invalid-argument': 400,
  unauthenticated: 401,
  'permission-denied': 403,
  'not-found': 404,
  'already-exists': 409,
  'failed-precondition': 409,
  'resource-exhausted': 429,
  unavailable: 503,
};

const fail = (code: string, message: string): never => {
  throw new HttpException({ statusCode: STATUS[code], code, message }, STATUS[code]);
};
const check = (ok: unknown, message = 'Bạn không có quyền thực hiện thao tác này.') => {
  if (!ok) fail('permission-denied', message);
};
const id = (value: unknown): string => {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(value)) {
    fail('invalid-argument', 'Mã không hợp lệ.');
  }
  return value as string;
};
const str = (value: unknown, max: number, required = false): string => {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) {
    fail('invalid-argument', 'Nội dung trống hoặc quá dài.');
  }
  return (value as string).trim();
};
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');
export const pairId = (a: string, b: string) => sha256(JSON.stringify([a, b].sort()));

const SCHEMAS: Record<string, string[]> = {
  bootstrap: [],
  profile: ['target'],
  saveProfile: ['name', 'bio'],
  search: ['handle'],
  feed: ['space', 'cursor', 'author', 'mood'],
  post: ['space', 'postId'],
  createPost: ['space', 'text', 'mood', 'intent', 'image'],
  deletePost: ['space', 'postId'],
  toggleComments: ['space', 'postId', 'enabled'],
  react: ['space', 'postId', 'enabled'],
  comments: ['space', 'postId', 'cursor'],
  comment: ['space', 'postId', 'text'],
  deleteComment: ['space', 'postId', 'commentId'],
  groups: [],
  createGroup: ['name', 'description'],
  group: ['space'],
  invite: ['space', 'target'],
  groupAction: ['space', 'kind', 'target'],
  connections: [],
  friendship: ['target', 'kind'],
  messages: ['target', 'cursor'],
  sendMessage: ['target', 'text', 'image'],
  image: ['space', 'postId', 'target', 'messageId'],
  report: ['space', 'postId', 'commentId', 'target', 'messageId', 'reason'],
  reports: ['cursor'],
  reportImage: ['reportId'],
  moderate: ['reportId', 'kind'],
};
const MUTATIONS = new Set([
  'saveProfile',
  'createPost',
  'deletePost',
  'toggleComments',
  'react',
  'comment',
  'deleteComment',
  'createGroup',
  'invite',
  'groupAction',
  'friendship',
  'sendMessage',
  'report',
  'moderate',
]);
const MOODS = ['', 'Vui vẻ', 'Bình yên', 'Buồn', 'Lo lắng', 'Áp lực', 'Tức giận', 'Biết ơn', 'Mệt mỏi'];
const INTENTS = [
  '',
  'Chỉ muốn được lắng nghe',
  'Muốn nghe lời khuyên',
  'Có ai từng trải qua không?',
  'Chia sẻ chuyện vui',
];
const PAGE_SIZE = 20;

export function validateRequest(d: unknown): Json {
  if (!d || Array.isArray(d) || typeof d !== 'object') fail('invalid-argument', 'Thao tác không hợp lệ.');
  const data = d as Json;
  if (typeof data.action !== 'string' || !Object.prototype.hasOwnProperty.call(SCHEMAS, data.action)) {
    fail('invalid-argument', 'Thao tác không hợp lệ.');
  }
  const allowed = ['action', ...(MUTATIONS.has(data.action) ? ['requestId'] : []), ...SCHEMAS[data.action]];
  if (Object.keys(data).some((k) => !allowed.includes(k))) {
    fail('invalid-argument', 'Dữ liệu chứa trường không được phép.');
  }
  if (MUTATIONS.has(data.action)) id(data.requestId);
  for (const k of ['space', 'postId', 'commentId', 'target', 'messageId', 'reportId', 'author']) {
    if (data[k] !== undefined) id(data[k]);
  }
  if (data.mood !== undefined && (typeof data.mood !== 'string' || !MOODS.includes(data.mood))) {
    fail('invalid-argument', 'Cảm xúc không hợp lệ.');
  }
  if (data.cursor !== undefined && data.cursor !== null) {
    const c = data.cursor;
    if (
      typeof c !== 'object' ||
      Array.isArray(c) ||
      Object.keys(c).some((k) => !['seconds', 'nanoseconds', 'id'].includes(k)) ||
      !Number.isInteger(c.seconds) ||
      !Number.isInteger(c.nanoseconds) ||
      c.nanoseconds < 0 ||
      c.nanoseconds > 999999999
    ) {
      fail('invalid-argument', 'Trang không hợp lệ.');
    }
    id(c.id);
  }
  return data;
}

const millis = (date: Date | null | undefined) => (date ? date.getTime() : null);
const profileOut = (p: CommunityProfile) => ({ id: p.uid, name: p.name, bio: p.bio, handle: p.handle });
const relationOut = (r: Relation) => ({
  members: r.members,
  requestedBy: r.requestedBy,
  status: r.status,
  blockedBy: r.blockedBy,
  hasMessages: r.hasMessages,
  lastSender: r.lastSender ?? null,
  lastMessageAt: millis(r.lastMessageAt),
});
const postOut = (p: CommunityPost) => ({
  id: p.id,
  author: p.author,
  authorName: p.authorName,
  text: p.text,
  mood: p.mood,
  intent: p.intent,
  imagePath: p.imagePath,
  createdAt: millis(p.createdAt),
  deleted: p.deleted,
  ready: p.ready,
  commentsOpen: p.commentsOpen,
  likes: p.likes,
});
const groupOut = (g: CommunityGroup) => ({
  id: g.id,
  name: g.name,
  description: g.description,
  owner: g.owner,
  members: g.members,
  invited: g.invited,
  closed: g.closed,
  createdAt: millis(g.createdAt),
});
const commentOut = (c: CommunityComment) => ({
  id: c.id,
  author: c.author,
  authorName: c.authorName,
  text: c.text,
  createdAt: millis(c.createdAt),
  deleted: c.deleted,
});
const messageOut = (m: CommunityMessage) => ({
  id: m.id,
  author: m.author,
  text: m.text,
  imagePath: m.imagePath,
  createdAt: millis(m.createdAt),
  deleted: m.deleted,
  ready: m.ready,
});
const reportOut = (r: CommunityReport) => ({
  id: r.id,
  reporter: r.reporter,
  target: r.target,
  path: r.path,
  evidence: r.evidence,
  imagePath: r.imagePath,
  reason: r.reason,
  status: r.status,
  resolution: r.resolution,
  moderator: r.moderator,
  resolvedAt: millis(r.resolvedAt),
  createdAt: millis(r.createdAt),
});

@Injectable()
export class CommunityService {
  constructor(@InjectDataSource() private dataSource: DataSource) {}

  async handle(user: User, body: unknown): Promise<Json> {
    const d = validateRequest(body);
    const uid = user.id;
    const isAdmin = user.communityAdmin === true;
    const write = MUTATIONS.has(d.action);
    const fingerprint = write ? sha256(JSON.stringify(d)) : '';

    // Trừ hạn mức trước khi giải mã ảnh hay đọc dữ liệu; lần thử lại cũng bị tính.
    await this.charge(uid, write);
    const photo = await this.processImage(d.image);

    return this.serializable((m) => this.run(m, d, uid, isAdmin, write, fingerprint, photo));
  }

  // Firestore transaction tương đương SERIALIZABLE; Postgres có thể huỷ khi xung đột
  // (40001) hoặc deadlock (40P01) nên thử lại vài lần.
  private async serializable<T>(work: (m: EntityManager) => Promise<T>): Promise<T> {
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.dataSource.transaction('SERIALIZABLE', work);
      } catch (error: any) {
        const code = error?.driverError?.code ?? error?.code;
        if ((code === '40001' || code === '40P01') && attempt < 4) continue;
        throw error;
      }
    }
  }

  private needsSupport(text: string): boolean {
    const normalized = text.toLowerCase();
    return CRISIS_KEYWORDS.some((keyword) => normalized.includes(keyword));
  }

  private async charge(uid: string, write: boolean) {
    const key = `${uid}_${write ? 'write' : 'read'}`;
    const limit = write ? 40 : 240;
    await this.dataSource.transaction(async (m) => {
      const now = Date.now();
      await m
        .createQueryBuilder()
        .insert()
        .into(CommunityLimit)
        .values({ key, start: String(now), count: 0 })
        .orIgnore()
        .execute();
      const rate = await m.findOne(CommunityLimit, { where: { key }, lock: { mode: 'pessimistic_write' } });
      const start = Number(rate!.start);
      const count = now - start < 60000 ? rate!.count : 0;
      if (count >= limit) fail('resource-exhausted', 'Bạn thao tác hơi nhanh. Hãy thử lại sau một phút.');
      await m.update(CommunityLimit, { key }, { start: String(count === 0 ? now : start), count: count + 1 });
    });
  }

  private async processImage(image: unknown): Promise<Buffer | null> {
    if (image === undefined || image === null || image === '') return null;
    str(image, 1400000, true);
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(image as string)) fail('invalid-argument', 'Ảnh không hợp lệ.');
    const bytes = Buffer.from(image as string, 'base64');
    const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
    const png = bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    if (!jpeg && !png) fail('invalid-argument', 'Chỉ hỗ trợ ảnh JPEG hoặc PNG.');
    let photo: Buffer;
    try {
      // Mã hoá lại để loại bỏ EXIF/GPS và payload ẩn; giới hạn pixel chống bom giải nén.
      photo = await sharp(bytes, { limitInputPixels: 16000000 })
        .rotate()
        .resize(1280, 1280, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 75 })
        .toBuffer();
    } catch {
      return fail('invalid-argument', 'Không đọc được ảnh. Hãy chọn ảnh JPEG hoặc PNG khác.');
    }
    if (photo.length > 900000) fail('invalid-argument', 'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn.');
    return photo;
  }

  private async page<T extends ObjectLiteral>(
    qb: SelectQueryBuilder<T>,
    cursor: Cursor | null | undefined,
    serialize: (row: T) => Json,
  ) {
    qb.orderBy('x.createdAt', 'DESC').addOrderBy('x.id', 'DESC');
    if (cursor) {
      const ts = new Date(cursor.seconds * 1000 + Math.floor(cursor.nanoseconds / 1e6));
      qb.andWhere('(x.createdAt < :ts OR (x.createdAt = :ts AND x.id < :cid))', { ts, cid: cursor.id });
    }
    const rows = await qb.limit(PAGE_SIZE).getMany();
    const last = rows.at(-1) as any;
    return {
      items: rows.map(serialize),
      cursor:
        rows.length === PAGE_SIZE
          ? {
              seconds: Math.floor(last.createdAt.getTime() / 1000),
              nanoseconds: (last.createdAt.getTime() % 1000) * 1e6,
              id: last.id,
            }
          : null,
    };
  }

  private async run(
    m: EntityManager,
    d: Json,
    uid: string,
    isAdmin: boolean,
    write: boolean,
    fingerprint: string,
    photo: Buffer | null,
  ): Promise<Json> {
    const me = await m.findOne(CommunityProfile, { where: { uid } });
    if (me?.suspended && !isAdmin) fail('permission-denied', 'Tài khoản cộng đồng đang bị tạm khóa.');

    if (write) {
      const previous = await m.findOne(CommunityOperation, { where: { uid, requestId: d.requestId } });
      if (previous) {
        if (previous.fingerprint !== fingerprint) {
          fail('already-exists', 'Yêu cầu đã được sử dụng cho nội dung khác.');
        }
        return previous.result;
      }
    }

    const stamp = new Date();
    const qb = <T extends ObjectLiteral>(entity: EntityTarget<T>) => m.createQueryBuilder(entity, 'x');

    const profile = async (target: string) => {
      const p = await m.findOne(CommunityProfile, { where: { uid: target } });
      if (!p) fail('not-found', 'Người này chưa tạo hồ sơ cộng đồng.');
      return profileOut(p!);
    };
    const relation = async (target: string): Promise<Relation> => {
      id(target);
      check(target !== uid, 'Không thể thực hiện với chính mình.');
      return (
        (await m.findOne(CommunityConnection, { where: { id: pairId(uid, target) } })) ?? {
          members: [uid, target].sort(),
          requestedBy: '',
          status: 'none',
          blockedBy: [],
          hasMessages: false,
        }
      );
    };
    const saveRelation = (target: string, r: Relation) =>
      m.save(CommunityConnection, {
        id: pairId(uid, target),
        members: r.members,
        requestedBy: r.requestedBy,
        status: r.status,
        blockedBy: r.blockedBy,
        hasMessages: r.hasMessages,
        lastSender: r.lastSender ?? null,
        lastMessageAt: r.lastMessageAt ?? null,
      });
    const unblocked = (r: Relation) =>
      check(r.blockedBy.length === 0, 'Không thể tương tác khi một trong hai người đã chặn.');
    const spaceAccess = async (space: string) => {
      id(space);
      if (space === 'public') return null;
      const group = await m.findOne(CommunityGroup, { where: { id: space } });
      check(
        group && !group.closed && group.members.includes(uid),
        'Bạn không còn là thành viên của nhóm này.',
      );
      return group!;
    };
    const postAccess = async () => {
      const group = await spaceAccess(d.space);
      const post = await m.findOne(CommunityPost, { where: { space: d.space, id: id(d.postId) } });
      if (!post || post.deleted || post.ready === false) fail('not-found', 'Bài viết đã được gỡ.');
      if (post!.author !== uid) {
        const rel = await relation(post!.author);
        check(!rel.blockedBy.includes(uid), 'Bạn đã chặn tác giả này.');
      }
      return { group, post: post! };
    };
    const hiddenAuthors = async () => {
      const blocked = await qb(CommunityConnection)
        .where(':uid = ANY(x.blockedBy)', { uid })
        .getMany();
      return [...new Set(blocked.flatMap((r) => r.members.filter((x) => x !== uid)))];
    };
    const content = () => {
      const text = str(d.text ?? '', 4000);
      if (!text && !photo) fail('invalid-argument', 'Hãy viết vài dòng hoặc thêm một ảnh.');
      return text;
    };
    const ownId = () => sha256(`${uid}:${d.requestId}`);
    const memberGroupCount = (person: string) =>
      qb(CommunityGroup).where(':person = ANY(x.members)', { person }).limit(100).getCount();
    const media = async (path: string) => {
      const row = await m.findOne(CommunityMedia, { where: { path } });
      if (!row) fail('unavailable', 'Ảnh chưa tải được. Hãy thử lại.');
      return { image: row!.bytes.toString('base64') };
    };
    const audit = (kind: string, reportId: string | null = null) =>
      m.insert(CommunityAudit, { moderator: uid, kind, reportId, createdAt: stamp });

    let out: Json = {};

    if (d.action === 'bootstrap') {
      let pending = 0;
      let unread = 0;
      let invites = 0;
      if (me) {
        const connections = await qb(CommunityConnection)
          .where(':uid = ANY(x.members)', { uid })
          .limit(200)
          .getMany();
        for (const r of connections) {
          if (r.status === 'pending' && r.requestedBy !== uid && !r.blockedBy.length) pending++;
          if (r.lastSender && r.lastSender !== uid && !r.blockedBy.length) {
            const mark = await m.findOne(CommunityRead, { where: { connectionId: r.id, uid } });
            if (!mark || (r.lastMessageAt?.getTime() ?? 0) > mark.at.getTime()) unread++;
          }
        }
        invites = await qb(CommunityGroup).where(':uid = ANY(x.invited)', { uid }).limit(100).getCount();
      }
      out = { me: me ? profileOut(me) : null, admin: isAdmin, pending, unread, invites };
    } else if (d.action === 'saveProfile') {
      const name = str(d.name, 40, true);
      const bio = str(d.bio ?? '', 160);
      const handle = me?.handle || randomBytes(6).toString('hex');
      if (!me) {
        check(!(await m.findOne(CommunityProfile, { where: { handle } })), 'Hãy thử tạo hồ sơ lại.');
      }
      await m.save(CommunityProfile, {
        uid,
        name,
        bio,
        handle,
        createdAt: me?.createdAt || stamp,
        suspended: me?.suspended || false,
      });
    } else {
      check(!!me, 'Hãy tạo biệt danh cộng đồng trước.');
      switch (d.action) {
        case 'profile': {
          const p = await profile(id(d.target));
          out = { profile: p, relation: d.target === uid ? null : relationOut(await relation(d.target)) };
          break;
        }
        case 'search': {
          const handle = str(d.handle, 12, true).toLowerCase().replace(/^@/, '');
          const found = await m.findOne(CommunityProfile, { where: { handle: id(handle) } });
          out = { profile: found ? profileOut(found) : null };
          break;
        }
        case 'feed': {
          const group = await spaceAccess(d.space);
          const query = qb(CommunityPost)
            .where('x.space = :space', { space: d.space })
            .andWhere('x.deleted = false AND x.ready = true');
          if (d.author) query.andWhere('x.author = :author', { author: d.author });
          if (d.mood) query.andWhere('x.mood = :mood', { mood: d.mood });
          const hidden = await hiddenAuthors();
          if (hidden.length) query.andWhere('x.author NOT IN (:...hidden)', { hidden });
          out = await this.page(query, d.cursor, postOut);
          const postIds = out.items.map((p: Json) => p.id as string);
          const liked = new Set(
            postIds.length
              ? (
                  await m.find(CommunityReaction, {
                    where: { space: d.space, uid, postId: In(postIds) },
                  })
                ).map((reaction) => reaction.postId)
              : [],
          );
          for (const p of out.items) {
            p.liked = liked.has(p.id);
            p.canDelete = p.author === uid || group?.owner === uid || isAdmin;
          }
          break;
        }
        case 'post': {
          const { group, post } = await postAccess();
          out = {
            post: {
              ...postOut(post),
              canDelete: post.author === uid || group?.owner === uid || isAdmin,
              liked: !!(await m.findOne(CommunityReaction, {
                where: { space: d.space, postId: post.id, uid },
              })),
            },
          };
          break;
        }
        case 'createPost': {
          await spaceAccess(d.space);
          const text = content();
          if (d.space === 'public' && this.needsSupport(text)) {
            fail(
              'failed-precondition',
              'Nội dung này có tín hiệu cần hỗ trợ. Hãy giữ riêng hoặc nhắn người bạn tin, đừng đăng công khai.',
            );
          }
          const mood = str(d.mood ?? '', 30);
          const intent = str(d.intent ?? '', 60);
          if (!MOODS.includes(mood) || !INTENTS.includes(intent)) {
            fail('invalid-argument', 'Cảm xúc hoặc lựa chọn phản hồi không hợp lệ.');
          }
          const postId = ownId();
          const imagePath = photo ? `community-media/posts/${d.space}/${postId}.jpg` : '';
          // Ảnh và bài viết cùng một transaction: không còn trạng thái "ready=false" như bản Storage.
          if (photo) await m.save(CommunityMedia, { path: imagePath, bytes: photo });
          await m.insert(CommunityPost, {
            space: d.space,
            id: postId,
            author: uid,
            authorName: me!.name,
            text,
            mood,
            intent,
            imagePath,
            createdAt: stamp,
            deleted: false,
            ready: true,
            commentsOpen: true,
            likes: 0,
          });
          out = { id: postId };
          break;
        }
        case 'deletePost':
        case 'toggleComments':
        case 'react':
        case 'comment':
        case 'comments':
        case 'deleteComment': {
          const { group, post } = await postAccess();
          const key = { space: d.space, id: post.id };
          if (d.action === 'deletePost') {
            check(post.author === uid || group?.owner === uid || isAdmin);
            await m.update(CommunityPost, key, { deleted: true, text: '', imagePath: '' });
            if (post.imagePath) await m.delete(CommunityMedia, { path: post.imagePath });
          } else if (d.action === 'toggleComments') {
            check(post.author === uid);
            if (typeof d.enabled !== 'boolean') fail('invalid-argument', 'Lựa chọn không hợp lệ.');
            await m.update(CommunityPost, key, { commentsOpen: d.enabled });
          } else if (d.action === 'react') {
            if (post.author !== uid) unblocked(await relation(post.author));
            if (typeof d.enabled !== 'boolean') fail('invalid-argument', 'Lựa chọn không hợp lệ.');
            const reactionKey = { space: d.space, postId: post.id, uid };
            const exists = !!(await m.findOne(CommunityReaction, { where: reactionKey }));
            const likes = post.likes + (exists === d.enabled ? 0 : d.enabled ? 1 : -1);
            out = { liked: d.enabled, likes };
            if (exists !== d.enabled) {
              await m.update(CommunityPost, key, { likes });
              if (d.enabled) await m.insert(CommunityReaction, { ...reactionKey, createdAt: stamp });
              else await m.delete(CommunityReaction, reactionKey);
            }
          } else if (d.action === 'comment') {
            check(post.commentsOpen, 'Tác giả đã tắt bình luận.');
            if (post.author !== uid) unblocked(await relation(post.author));
            const commentId = ownId();
            await m.insert(CommunityComment, {
              space: d.space,
              postId: post.id,
              id: commentId,
              author: uid,
              authorName: me!.name,
              text: str(d.text, 2000, true),
              createdAt: stamp,
              deleted: false,
            });
            out = { id: commentId };
          } else if (d.action === 'deleteComment') {
            const commentKey = { space: d.space, postId: post.id, id: id(d.commentId) };
            const comment = await m.findOne(CommunityComment, { where: commentKey });
            check(comment && (comment.author === uid || group?.owner === uid || isAdmin));
            await m.update(CommunityComment, commentKey, { deleted: true, text: '' });
          } else {
            const query = qb(CommunityComment)
              .where('x.space = :space AND x.postId = :postId', { space: d.space, postId: post.id })
              .andWhere('x.deleted = false');
            const hidden = await hiddenAuthors();
            if (hidden.length) query.andWhere('x.author NOT IN (:...hidden)', { hidden });
            out = await this.page(query, d.cursor, (c) => ({
              ...commentOut(c),
              canDelete: c.author === uid || group?.owner === uid || isAdmin,
            }));
          }
          break;
        }
        case 'groups': {
          const member = await qb(CommunityGroup)
            .where(':uid = ANY(x.members) AND x.closed = false', { uid })
            .limit(100)
            .getMany();
          const invites = await qb(CommunityGroup)
            .where(':uid = ANY(x.invited) AND x.closed = false', { uid })
            .limit(100)
            .getMany();
          out = {
            items: member.map(groupOut),
            invites: invites.map((g) => ({
              id: g.id,
              name: g.name,
              description: g.description,
              closed: g.closed,
            })),
          };
          break;
        }
        case 'createGroup': {
          check((await memberGroupCount(uid)) < 100, 'Bạn đã đạt giới hạn 100 nhóm.');
          const groupId = ownId();
          await m.insert(CommunityGroup, {
            id: groupId,
            name: str(d.name, 60, true),
            description: str(d.description ?? '', 240),
            owner: uid,
            members: [uid],
            invited: [],
            closed: false,
            createdAt: stamp,
          });
          out = { id: groupId };
          break;
        }
        case 'group': {
          const g = await spaceAccess(d.space);
          check(!!g);
          const members: Json[] = [];
          for (const target of g!.members) members.push(await profile(target));
          const invited: Json[] = [];
          if (g!.owner === uid) for (const target of g!.invited) invited.push(await profile(target));
          out = { group: groupOut(g!), members, invited };
          break;
        }
        case 'invite': {
          const g = await spaceAccess(d.space);
          check(g?.owner === uid);
          await profile(id(d.target));
          unblocked(await relation(d.target));
          check(!g!.members.includes(d.target), 'Người này đã ở trong nhóm.');
          check(g!.invited.length < 50, 'Nhóm đã có đủ 50 lời mời.');
          await m.update(CommunityGroup, { id: g!.id }, { invited: [...new Set([...g!.invited, d.target])] });
          break;
        }
        case 'groupAction': {
          const g = await m.findOne(CommunityGroup, { where: { id: id(d.space) } });
          check(g && !g.closed);
          const group = g!;
          const kind = str(d.kind, 20, true);
          const target = d.target as string | undefined;
          if (kind === 'accept' || kind === 'decline') {
            check(group.invited.includes(uid));
            if (kind === 'accept') {
              unblocked(await relation(group.owner));
              check(group.members.length < 50, 'Nhóm đã đủ 50 thành viên.');
              check((await memberGroupCount(uid)) < 100, 'Bạn đã đạt giới hạn 100 nhóm.');
            }
            await m.update(
              CommunityGroup,
              { id: group.id },
              {
                invited: group.invited.filter((x) => x !== uid),
                members: kind === 'accept' ? [...new Set([...group.members, uid])] : group.members,
              },
            );
          } else if (kind === 'leave') {
            check(
              group.members.includes(uid) && group.owner !== uid,
              'Chủ nhóm cần chuyển quyền hoặc đóng nhóm trước.',
            );
            await m.update(CommunityGroup, { id: group.id }, { members: group.members.filter((x) => x !== uid) });
          } else {
            check(group.owner === uid);
            if (kind === 'remove') {
              check(target && target !== uid);
              await m.update(
                CommunityGroup,
                { id: group.id },
                {
                  members: group.members.filter((x) => x !== target),
                  invited: group.invited.filter((x) => x !== target),
                },
              );
            } else if (kind === 'transfer') {
              check(target && group.members.includes(target) && target !== uid);
              await m.update(CommunityGroup, { id: group.id }, { owner: target });
            } else if (kind === 'close') {
              await m.update(CommunityGroup, { id: group.id }, { closed: true, members: [], invited: [] });
            } else {
              fail('invalid-argument', 'Thao tác nhóm không hợp lệ.');
            }
          }
          break;
        }
        case 'connections': {
          const connections = await qb(CommunityConnection)
            .where(':uid = ANY(x.members)', { uid })
            .limit(200)
            .getMany();
          const items: Json[] = [];
          for (const r of connections) {
            const target = r.members.find((x) => x !== uid)!;
            const p = await m.findOne(CommunityProfile, { where: { uid: target } });
            // Tài khoản đã xoá: bỏ qua thay vì làm hỏng cả danh sách.
            if (!p) continue;
            const latest = await m.find(CommunityMessage, {
              where: { connectionId: r.id, ready: true },
              order: { createdAt: 'DESC' },
              take: 1,
            });
            const message = latest[0];
            const mark = await m.findOne(CommunityRead, { where: { connectionId: r.id, uid } });
            const lastMessageAt = message?.createdAt?.getTime() || 0;
            const preview = !message
              ? ''
              : message.deleted
                ? 'Tin nhắn đã được gỡ'
                : message.text || 'Ảnh đính kèm';
            const unread =
              !!message &&
              message.author !== uid &&
              !r.blockedBy.length &&
              (!mark || lastMessageAt > mark.at.getTime());
            items.push({ id: r.id, ...relationOut(r), lastMessageAt, preview, unread, profile: profileOut(p) });
          }
          items.sort((a, b) => b.lastMessageAt - a.lastMessageAt || a.id.localeCompare(b.id));
          out = { items };
          break;
        }
        case 'friendship': {
          await profile(id(d.target));
          const r = await relation(d.target);
          const kind = str(d.kind, 20, true);
          if (kind === 'block') {
            r.blockedBy = [...new Set([...r.blockedBy, uid])];
            r.status = 'none';
            r.requestedBy = '';
          } else if (kind === 'unblock') {
            r.blockedBy = r.blockedBy.filter((x) => x !== uid);
          } else {
            unblocked(r);
            if (kind === 'request') {
              check(r.status === 'none', 'Đã có lời mời hoặc đã là bạn bè.');
              for (const person of [uid, d.target]) {
                const all = await qb(CommunityConnection)
                  .where(':person = ANY(x.members)', { person })
                  .limit(200)
                  .getCount();
                check(all < 200, 'Danh sách kết nối đã đầy.');
              }
              r.status = 'pending';
              r.requestedBy = uid;
            } else if (kind === 'accept') {
              check(r.status === 'pending' && r.requestedBy === d.target);
              r.status = 'accepted';
            } else if (kind === 'decline') {
              check(r.status === 'pending' && r.requestedBy === d.target);
              r.status = 'none';
              r.requestedBy = '';
            } else if (kind === 'cancel') {
              check(r.status === 'pending' && r.requestedBy === uid);
              r.status = 'none';
              r.requestedBy = '';
            } else if (kind === 'unfriend') {
              check(r.status === 'accepted');
              r.status = 'none';
              r.requestedBy = '';
            } else {
              fail('invalid-argument', 'Thao tác kết bạn không hợp lệ.');
            }
          }
          await saveRelation(d.target, r);
          break;
        }
        case 'messages':
        case 'sendMessage': {
          const r = await relation(d.target);
          const connectionId = pairId(uid, d.target);
          check(r.status === 'accepted' || r.hasMessages, 'Hãy kết bạn trước khi nhắn tin.');
          if (d.action === 'messages') {
            unblocked(r);
            const query = qb(CommunityMessage)
              .where('x.connectionId = :connectionId', { connectionId })
              .andWhere('x.ready = true');
            out = await this.page(query, d.cursor, messageOut);
            out.relation = relationOut(r);
            if (!d.cursor) await m.save(CommunityRead, { connectionId, uid, at: stamp });
          } else {
            unblocked(r);
            check(r.status === 'accepted', 'Hai bạn cần kết bạn lại để gửi tin.');
            const messageId = ownId();
            const imagePath = photo ? `community-media/messages/${connectionId}/${messageId}.jpg` : '';
            if (photo) await m.save(CommunityMedia, { path: imagePath, bytes: photo });
            await m.insert(CommunityMessage, {
              connectionId,
              id: messageId,
              author: uid,
              text: content(),
              imagePath,
              createdAt: stamp,
              deleted: false,
              ready: true,
            });
            await saveRelation(d.target, { ...r, hasMessages: true, lastSender: uid, lastMessageAt: stamp });
            out = { id: messageId };
          }
          break;
        }
        case 'image': {
          let data: { deleted: boolean; ready: boolean; imagePath: string } | null;
          if (d.messageId) {
            const r = await relation(d.target);
            check(r.hasMessages);
            unblocked(r);
            data = await m.findOne(CommunityMessage, {
              where: { connectionId: pairId(uid, d.target), id: id(d.messageId) },
            });
          } else {
            data = (await postAccess()).post;
          }
          check(data && !data.deleted && data.ready !== false && data.imagePath);
          out = await media(data!.imagePath);
          break;
        }
        case 'report': {
          const reason = str(d.reason, 500, true);
          let target: string;
          let path: string;
          let evidence: string;
          let imagePath = '';
          if (d.messageId) {
            const r = await relation(d.target);
            check(r.hasMessages);
            const connectionId = pairId(uid, d.target);
            const message = await m.findOne(CommunityMessage, {
              where: { connectionId, id: id(d.messageId) },
            });
            check(!!message);
            target = message!.author;
            path = `messages/${connectionId}/${message!.id}`;
            evidence = message!.text;
            imagePath = message!.imagePath || '';
          } else if (d.postId) {
            const { post } = await postAccess();
            target = post.author;
            path = `posts/${d.space}/${post.id}`;
            evidence = post.text;
            imagePath = post.imagePath || '';
            if (d.commentId) {
              const comment = await m.findOne(CommunityComment, {
                where: { space: d.space, postId: post.id, id: id(d.commentId) },
              });
              check(!!comment);
              target = comment!.author;
              path = `comments/${d.space}/${post.id}/${comment!.id}`;
              evidence = comment!.text;
              imagePath = '';
            }
          } else {
            target = id(d.target);
            await profile(target);
            path = `profiles/${target}`;
            evidence = '';
          }
          check(target !== uid, 'Không thể báo cáo nội dung của chính mình.');
          await m.insert(CommunityReport, {
            id: ownId(),
            reporter: uid,
            target,
            path,
            evidence,
            imagePath,
            reason,
            status: 'open',
            createdAt: stamp,
          });
          break;
        }
        case 'reports': {
          check(isAdmin);
          out = await this.page(qb(CommunityReport), d.cursor, reportOut);
          await audit('reviewReports');
          break;
        }
        case 'reportImage': {
          check(isAdmin);
          const report = await m.findOne(CommunityReport, { where: { id: id(d.reportId) } });
          check(report && report.imagePath);
          out = await media(report!.imagePath);
          await audit('reviewImage', d.reportId);
          break;
        }
        case 'moderate': {
          check(isAdmin);
          const report = await m.findOne(CommunityReport, { where: { id: id(d.reportId) } });
          check(!!report);
          const kind = str(d.kind, 20, true);
          if (!['dismiss', 'remove', 'suspend', 'restore'].includes(kind)) {
            fail('invalid-argument', 'Thao tác xử lý không hợp lệ.');
          }
          if (kind === 'remove') {
            check(!report!.path.startsWith('profiles/'));
            await this.removeReported(m, report!.path);
          } else if (kind === 'suspend' || kind === 'restore') {
            await m.update(CommunityProfile, { uid: report!.target }, { suspended: kind === 'suspend' });
          }
          await m.update(
            CommunityReport,
            { id: report!.id },
            { status: 'resolved', resolution: kind, moderator: uid, resolvedAt: stamp },
          );
          await audit(kind, d.reportId);
          break;
        }
        default:
          fail('invalid-argument', 'Thao tác chưa hỗ trợ.');
      }
    }

    if (write) {
      await m.insert(CommunityOperation, {
        uid,
        requestId: d.requestId,
        fingerprint,
        result: out,
        createdAt: stamp,
      });
    }
    return out;
  }

  // Gỡ nội dung bị báo cáo theo đường dẫn logic đã lưu trong báo cáo.
  private async removeReported(m: EntityManager, path: string) {
    const [kind, ...parts] = path.split('/');
    let imagePath = '';
    if (kind === 'posts' && parts.length === 2) {
      const key = { space: parts[0], id: parts[1] };
      imagePath = (await m.findOne(CommunityPost, { where: key }))?.imagePath ?? '';
      await m.update(CommunityPost, key, { deleted: true, text: '', imagePath: '' });
    } else if (kind === 'comments' && parts.length === 3) {
      await m.update(
        CommunityComment,
        { space: parts[0], postId: parts[1], id: parts[2] },
        { deleted: true, text: '' },
      );
    } else if (kind === 'messages' && parts.length === 2) {
      const key = { connectionId: parts[0], id: parts[1] };
      imagePath = (await m.findOne(CommunityMessage, { where: key }))?.imagePath ?? '';
      await m.update(CommunityMessage, key, { deleted: true, text: '', imagePath: '' });
    }
    if (imagePath) await m.delete(CommunityMedia, { path: imagePath });
  }
}

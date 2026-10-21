import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { User } from './entities/user.entity';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { StorageFile } from '../storage/entities/storage-file.entity';
import { Post } from '../posts/entities/post.entity';
import { Friend } from '../friends/entities/friend.entity';
import { escapeLike, pageParams } from '../common/pagination';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    @InjectRepository(StorageFile)
    private filesRepository: Repository<StorageFile>,
    @InjectRepository(Post)
    private postsRepository: Repository<Post>,
    @InjectRepository(Friend)
    private friendsRepository: Repository<Friend>,
  ) {}

  async findById(id: string, viewerId?: string): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    return this.toUserResponse(user, user.id === viewerId);
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { email } });
  }

  async search(query: string, limit?: unknown): Promise<any[]> {
    const term = (query ?? '').trim();
    if (term.length < 2 || term.length > 50) {
      throw new BadRequestException('Từ khoá cần từ 2 đến 50 ký tự');
    }
    const pattern = `%${escapeLike(term)}%`;
    // Không tìm theo email: tránh dò/thu thập địa chỉ email của người khác.
    const users = await this.usersRepository.find({
      where: [{ username: ILike(pattern) }, { displayName: ILike(pattern) }],
      take: pageParams(1, limit, { maxLimit: 20 }).limit,
    });

    return users.map((user) => this.toUserResponse(user, false));
  }

  async updateProfile(id: string, updateProfileDto: UpdateProfileDto): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    Object.assign(user, updateProfileDto);
    await this.usersRepository.save(user);

    return this.toUserResponse(user, true);
  }

  async updateAvatar(id: string, fileId: string): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    const file = await this.filesRepository.findOne({ where: { id: fileId } });
    if (
      !file ||
      file.uploadedById !== id ||
      file.accessType !== 'public' ||
      !file.mimeType?.startsWith('image/')
    ) {
      throw new BadRequestException('Ảnh đại diện phải là ảnh công khai do bạn tải lên');
    }

    user.avatar = `/api/storage/${file.id}/content`;
    await this.usersRepository.save(user);

    return this.toUserResponse(user, true);
  }

  async getStats(id: string): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    // Đếm bằng COUNT thay vì nạp toàn bộ bài viết/bạn bè vào bộ nhớ.
    const [postsCount, friendsCount] = await Promise.all([
      this.postsRepository.count({ where: { authorId: id } }),
      this.friendsRepository.count({ where: { userId: id, status: 'accepted' } }),
    ]);

    return {
      id: user.id,
      username: user.username,
      postsCount,
      friendsCount,
      joinedAt: user.createdAt,
    };
  }

  private toUserResponse(user: User, isSelf: boolean): any {
    return {
      id: user.id,
      ...(isSelf ? { email: user.email } : {}),
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      avatar: user.avatar,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      ...(isSelf ? { updatedAt: user.updatedAt } : {}),
    };
  }
}

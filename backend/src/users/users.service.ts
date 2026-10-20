import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { User } from './entities/user.entity';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async findById(id: string): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    return this.toUserResponse(user);
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { email } });
  }

  async search(query: string, limit = 10): Promise<any[]> {
    const users = await this.usersRepository.find({
      where: [
        { username: Like(`%${query}%`) },
        { displayName: Like(`%${query}%`) },
        { email: Like(`%${query}%`) },
      ],
      take: limit,
    });

    return users.map((user) => this.toUserResponse(user));
  }

  async updateProfile(id: string, updateProfileDto: UpdateProfileDto): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    Object.assign(user, updateProfileDto);
    await this.usersRepository.save(user);

    return this.toUserResponse(user);
  }

  async updateAvatar(id: string, avatar: string): Promise<any> {
    const user = await this.usersRepository.findOne({ where: { id } });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    user.avatar = avatar;
    await this.usersRepository.save(user);

    return this.toUserResponse(user);
  }

  async getStats(id: string): Promise<any> {
    const user = await this.usersRepository.findOne({
      where: { id },
      relations: ['posts', 'friends'],
    });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    return {
      id: user.id,
      username: user.username,
      postsCount: user.posts?.length || 0,
      friendsCount: user.friends?.length || 0,
      joinedAt: user.createdAt,
    };
  }

  private toUserResponse(user: User): any {
    return {
      id: user.id,
      email: user.email,
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      avatar: user.avatar,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }
}

import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, Or } from 'typeorm';
import { Friend } from './entities/friend.entity';
import { FriendRequest } from './entities/friend-request.entity';
import { User } from '../users/entities/user.entity';
import { AddFriendDto } from './dto/add-friend.dto';

@Injectable()
export class FriendsService {
  constructor(
    @InjectRepository(Friend)
    private friendsRepository: Repository<Friend>,
    @InjectRepository(FriendRequest)
    private friendRequestsRepository: Repository<FriendRequest>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  // Get list of friends for a user
  async getFriends(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    const [friends, total] = await this.friendsRepository.findAndCount({
      where: { userId, status: 'accepted' },
      relations: ['friend'],
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data: friends.map((f) => this.formatFriendResponse(f)),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Send friend request
  async sendFriendRequest(senderId: string, addFriendDto: AddFriendDto) {
    const recipient = await this.usersRepository.findOne({
      where: { id: addFriendDto.friendId },
    });

    if (!recipient) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    if (senderId === addFriendDto.friendId) {
      throw new BadRequestException('Không thể gửi lời mời cho chính mình');
    }

    // Check if already friends
    const existingFriend = await this.friendsRepository.findOne({
      where: [
        { userId: senderId, friendId: addFriendDto.friendId },
        { userId: addFriendDto.friendId, friendId: senderId },
      ],
    });

    if (existingFriend) {
      throw new ConflictException('Hai bạn đã là bạn bè');
    }

    // Check if request already exists
    const existingRequest = await this.friendRequestsRepository.findOne({
      where: [
        { senderId, recipientId: addFriendDto.friendId },
        { senderId: addFriendDto.friendId, recipientId: senderId },
      ],
    });

    if (existingRequest) {
      throw new ConflictException('Lời mời kết bạn đã được gửi');
    }

    // Create friend request
    const request = this.friendRequestsRepository.create({
      senderId,
      recipientId: addFriendDto.friendId,
    });

    await this.friendRequestsRepository.save(request);

    return {
      message: 'Lời mời kết bạn đã được gửi',
      data: await this.getFriendRequestWithSender(request.id),
    };
  }

  // Get incoming friend requests
  async getFriendRequests(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    const [requests, total] = await this.friendRequestsRepository.findAndCount({
      where: { recipientId: userId },
      relations: ['sender'],
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data: requests.map((r) => this.formatFriendRequestResponse(r)),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Accept friend request
  async acceptFriendRequest(userId: string, requestId: string) {
    const request = await this.friendRequestsRepository.findOne({
      where: { id: requestId, recipientId: userId },
      relations: ['sender', 'recipient'],
    });

    if (!request) {
      throw new NotFoundException('Lời mời kết bạn không tồn tại');
    }

    // Create bidirectional friendship
    const friendship1 = this.friendsRepository.create({
      userId: request.senderId,
      friendId: request.recipientId,
      status: 'accepted',
    });

    const friendship2 = this.friendsRepository.create({
      userId: request.recipientId,
      friendId: request.senderId,
      status: 'accepted',
    });

    await this.friendsRepository.save([friendship1, friendship2]);
    await this.friendRequestsRepository.delete(request.id);

    return {
      message: 'Đã chấp nhận lời mời kết bạn',
    };
  }

  // Reject/Delete friend request
  async rejectFriendRequest(userId: string, requestId: string) {
    const request = await this.friendRequestsRepository.findOne({
      where: {
        id: requestId,
        recipientId: userId,
      },
    });

    if (!request) {
      throw new NotFoundException('Lời mời kết bạn không tồn tại');
    }

    await this.friendRequestsRepository.delete(request.id);

    return {
      message: 'Đã từ chối lời mời kết bạn',
    };
  }

  // Remove friend
  async removeFriend(userId: string, friendId: string) {
    const friendship = await this.friendsRepository.findOne({
      where: { userId, friendId },
    });

    if (!friendship) {
      throw new NotFoundException('Không phải bạn bè');
    }

    // Remove both directions
    await this.friendsRepository.delete({
      userId,
      friendId,
    });

    await this.friendsRepository.delete({
      userId: friendId,
      friendId: userId,
    });

    return {
      message: 'Đã xóa bạn bè',
    };
  }

  // Get friend suggestions (users not already friends or requested)
  async getFriendSuggestions(userId: string, limit = 10) {
    // Get IDs of existing friends and friend requests
    const friendIds = await this.friendsRepository.find({
      where: [{ userId }, { friendId: userId }],
    });

    const friendIdSet = new Set<string>();
    friendIds.forEach((f) => {
      friendIdSet.add(f.userId);
      friendIdSet.add(f.friendId);
    });

    const requestIds = await this.friendRequestsRepository.find({
      where: [{ senderId: userId }, { recipientId: userId }],
    });

    const requestIdSet = new Set<string>();
    requestIds.forEach((r) => {
      requestIdSet.add(r.senderId);
      requestIdSet.add(r.recipientId);
    });

    // Combine all IDs to exclude
    const excludeIds = Array.from(
      new Set([...Array.from(friendIdSet), ...Array.from(requestIdSet), userId]),
    );

    // Get random users
    const suggestions = await this.usersRepository
      .createQueryBuilder('user')
      .where('user.id NOT IN (:...ids)', { ids: excludeIds })
      .orderBy('RANDOM()')
      .take(limit)
      .getMany();

    return {
      data: suggestions.map((u) => ({
        id: u.id,
        username: u.username,
        displayName: u.displayName,
        avatar: u.avatar,
        bio: u.bio,
      })),
    };
  }

  // Helper methods
  private formatFriendResponse(friend: Friend) {
    return {
      id: friend.id,
      userId: friend.userId,
      friendId: friend.friendId,
      friend: {
        id: friend.friend.id,
        username: friend.friend.username,
        displayName: friend.friend.displayName,
        avatar: friend.friend.avatar,
      },
      status: friend.status,
      createdAt: friend.createdAt,
      updatedAt: friend.updatedAt,
    };
  }

  private formatFriendRequestResponse(request: FriendRequest) {
    return {
      id: request.id,
      senderId: request.senderId,
      sender: {
        id: request.sender.id,
        username: request.sender.username,
        displayName: request.sender.displayName,
        avatar: request.sender.avatar,
      },
      recipientId: request.recipientId,
      createdAt: request.createdAt,
    };
  }

  private async getFriendRequestWithSender(requestId: string) {
    const request = await this.friendRequestsRepository.findOne({
      where: { id: requestId },
      relations: ['sender'],
    });
    if (!request) {
      throw new Error('Friend request not found');
    }
    return this.formatFriendRequestResponse(request);
  }
}

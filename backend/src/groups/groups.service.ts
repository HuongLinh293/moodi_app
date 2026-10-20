import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Group } from './entities/group.entity';
import { GroupMember } from './entities/group-member.entity';
import { GroupInvite } from './entities/group-invite.entity';
import { User } from '../users/entities/user.entity';
import { CreateGroupDto } from './dto/create-group.dto';
import { UpdateGroupDto } from './dto/update-group.dto';
import { AddMemberDto } from './dto/add-member.dto';

@Injectable()
export class GroupsService {
  constructor(
    @InjectRepository(Group)
    private groupsRepository: Repository<Group>,
    @InjectRepository(GroupMember)
    private groupMembersRepository: Repository<GroupMember>,
    @InjectRepository(GroupInvite)
    private groupInvitesRepository: Repository<GroupInvite>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  // Get all groups for a user
  async getGroups(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [groups, total] = await this.groupMembersRepository.findAndCount({
      where: { userId },
      relations: ['group', 'group.createdBy'],
      skip,
      take: limit,
      order: { joinedAt: 'DESC' },
    });

    return {
      data: groups.map((m) => this.formatGroupResponse(m.group)),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Create a new group
  async createGroup(userId: string, createGroupDto: CreateGroupDto) {
    const creator = await this.usersRepository.findOne({ where: { id: userId } });
    if (!creator) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    const group = this.groupsRepository.create({
      name: createGroupDto.name,
      description: createGroupDto.description,
      image: createGroupDto.image,
      createdById: userId,
    });

    const savedGroup = await this.groupsRepository.save(group);

    // Add creator as admin member
    await this.groupMembersRepository.save({
      groupId: savedGroup.id,
      userId: userId,
      role: 'admin',
    });

    return {
      message: 'Nhóm được tạo thành công',
      data: this.formatGroupResponse(savedGroup),
    };
  }

  // Get group details
  async getGroupById(id: string, userId?: string) {
    const group = await this.groupsRepository.findOne({
      where: { id },
      relations: ['createdBy'],
    });

    if (!group) {
      throw new NotFoundException('Nhóm không tồn tại');
    }

    // Get member count
    const memberCount = await this.groupMembersRepository.count({
      where: { groupId: id },
    });

    return {
      ...this.formatGroupResponse(group),
      memberCount,
      isMember: userId
        ? await this.isGroupMember(id, userId)
        : false,
    };
  }

  // Update group info
  async updateGroup(id: string, userId: string, updateGroupDto: UpdateGroupDto) {
    const group = await this.groupsRepository.findOne({ where: { id } });

    if (!group) {
      throw new NotFoundException('Nhóm không tồn tại');
    }

    // Check if user is admin
    const member = await this.groupMembersRepository.findOne({
      where: { groupId: id, userId },
    });

    if (!member || member.role !== 'admin') {
      throw new ForbiddenException(
        'Chỉ quản trị viên mới được phép sửa nhóm',
      );
    }

    Object.assign(group, updateGroupDto);
    await this.groupsRepository.save(group);

    return {
      message: 'Nhóm được cập nhật thành công',
      data: this.formatGroupResponse(group),
    };
  }

  // Delete group
  async deleteGroup(id: string, userId: string) {
    const group = await this.groupsRepository.findOne({ where: { id } });

    if (!group) {
      throw new NotFoundException('Nhóm không tồn tại');
    }

    if (group.createdById !== userId) {
      throw new ForbiddenException(
        'Chỉ người tạo nhóm mới được phép xoá',
      );
    }

    await this.groupsRepository.delete(id);

    return {
      message: 'Nhóm được xoá thành công',
    };
  }

  // Get group members
  async getGroupMembers(groupId: string, page = 1, limit = 10) {
    // Check if group exists
    await this.getGroupById(groupId);

    const skip = (page - 1) * limit;
    const [members, total] = await this.groupMembersRepository.findAndCount({
      where: { groupId },
      relations: ['user'],
      skip,
      take: limit,
      order: { joinedAt: 'DESC' },
    });

    return {
      data: members.map((m) => ({
        id: m.id,
        userId: m.userId,
        user: {
          id: m.user.id,
          username: m.user.username,
          displayName: m.user.displayName,
          avatar: m.user.avatar,
        },
        role: m.role,
        joinedAt: m.joinedAt,
      })),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Add member to group
  async addMember(groupId: string, userId: string, addMemberDto: AddMemberDto) {
    const group = await this.groupsRepository.findOne({ where: { id: groupId } });
    if (!group) {
      throw new NotFoundException('Nhóm không tồn tại');
    }

    const member = await this.groupMembersRepository.findOne({
      where: { groupId, userId },
    });

    if (!member || member.role !== 'admin') {
      throw new ForbiddenException(
        'Chỉ quản trị viên mới được phép thêm thành viên',
      );
    }

    const newMember = await this.groupMembersRepository.findOne({
      where: { groupId, userId: addMemberDto.userId },
    });

    if (newMember) {
      throw new BadRequestException(
        'Người dùng đã là thành viên của nhóm',
      );
    }

    const user = await this.usersRepository.findOne({
      where: { id: addMemberDto.userId },
    });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    const groupMember = this.groupMembersRepository.create({
      groupId,
      userId: addMemberDto.userId,
      role: 'member',
    });

    await this.groupMembersRepository.save(groupMember);

    return {
      message: 'Thành viên được thêm vào nhóm',
    };
  }

  // Remove member from group
  async removeMember(groupId: string, userId: string, targetUserId: string) {
    const group = await this.groupsRepository.findOne({ where: { id: groupId } });
    if (!group) {
      throw new NotFoundException('Nhóm không tồn tại');
    }

    // Check if requester is admin
    const requesterMember = await this.groupMembersRepository.findOne({
      where: { groupId, userId },
    });

    if (!requesterMember || requesterMember.role !== 'admin') {
      throw new ForbiddenException(
        'Chỉ quản trị viên mới được phép xoá thành viên',
      );
    }

    // Check if target member exists
    const targetMember = await this.groupMembersRepository.findOne({
      where: { groupId, userId: targetUserId },
    });

    if (!targetMember) {
      throw new NotFoundException('Thành viên không tồn tại trong nhóm');
    }

    // Don't allow removing the group creator
    if (group.createdById === targetUserId && userId !== targetUserId) {
      throw new ForbiddenException(
        'Không thể xoá người tạo nhóm',
      );
    }

    await this.groupMembersRepository.delete(targetMember.id);

    return {
      message: 'Thành viên được xoá khỏi nhóm',
    };
  }

  // Leave group
  async leaveGroup(groupId: string, userId: string) {
    const group = await this.groupsRepository.findOne({ where: { id: groupId } });
    if (!group) {
      throw new NotFoundException('Nhóm không tồn tại');
    }

    const member = await this.groupMembersRepository.findOne({
      where: { groupId, userId },
    });

    if (!member) {
      throw new NotFoundException('Bạn không phải thành viên của nhóm này');
    }

    // Don't allow creator to leave (must delete group instead)
    if (group.createdById === userId) {
      throw new BadRequestException(
        'Người tạo nhóm không thể rời khỏi. Hãy xoá nhóm nếu không muốn',
      );
    }

    await this.groupMembersRepository.delete(member.id);

    return {
      message: 'Bạn đã rời khỏi nhóm',
    };
  }

  // Helper methods
  private formatGroupResponse(group: Group) {
    return {
      id: group.id,
      name: group.name,
      description: group.description,
      image: group.image,
      createdBy: {
        id: group.createdBy?.id,
        username: group.createdBy?.username,
        displayName: group.createdBy?.displayName,
      },
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    };
  }

  private async isGroupMember(groupId: string, userId: string): Promise<boolean> {
    const member = await this.groupMembersRepository.findOne({
      where: { groupId, userId },
    });
    return !!member;
  }
}

import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { GroupsService } from './groups.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { UpdateGroupDto } from './dto/update-group.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('groups')
@ApiBearerAuth()
@Controller('groups')
export class GroupsController {
  constructor(private groupsService: GroupsService) {}

  @Get()
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách nhóm của người dùng' })
  async getGroups(
    @CurrentUser() user: User,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.groupsService.getGroups(user.id, page, limit);
  }

  @Post()
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Tạo nhóm mới' })
  async createGroup(
    @CurrentUser() user: User,
    @Body() createGroupDto: CreateGroupDto,
  ) {
    return this.groupsService.createGroup(user.id, createGroupDto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết nhóm' })
  async getGroupById(
    @Param('id') id: string,
    @CurrentUser() user?: User,
  ) {
    return this.groupsService.getGroupById(id, user?.id);
  }

  @Patch(':id')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Cập nhật thông tin nhóm' })
  async updateGroup(
    @Param('id') id: string,
    @CurrentUser() user: User,
    @Body() updateGroupDto: UpdateGroupDto,
  ) {
    return this.groupsService.updateGroup(id, user.id, updateGroupDto);
  }

  @Delete(':id')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá nhóm' })
  async deleteGroup(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.groupsService.deleteGroup(id, user.id);
  }

  @Get(':id/members')
  @ApiOperation({ summary: 'Danh sách thành viên nhóm' })
  async getGroupMembers(
    @Param('id') id: string,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.groupsService.getGroupMembers(id, page, limit);
  }

  @Post(':id/members')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Thêm thành viên vào nhóm' })
  async addMember(
    @Param('id') id: string,
    @CurrentUser() user: User,
    @Body() addMemberDto: AddMemberDto,
  ) {
    return this.groupsService.addMember(id, user.id, addMemberDto);
  }

  @Delete(':id/members/:userId')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá thành viên khỏi nhóm' })
  async removeMember(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: User,
  ) {
    return this.groupsService.removeMember(id, user.id, userId);
  }

  @Post(':id/leave')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Rời khỏi nhóm' })
  async leaveGroup(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.groupsService.leaveGroup(id, user.id);
  }
}

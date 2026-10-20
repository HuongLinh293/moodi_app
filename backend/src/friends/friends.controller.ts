import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { FriendsService } from './friends.service';
import { AddFriendDto } from './dto/add-friend.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('friends')
@ApiBearerAuth()
@Controller('friends')
export class FriendsController {
  constructor(private friendsService: FriendsService) {}

  @Get()
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách bạn bè' })
  async getFriends(
    @CurrentUser() user: User,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.friendsService.getFriends(user.id, page, limit);
  }

  @Post('requests')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Gửi lời mời kết bạn' })
  async sendFriendRequest(
    @CurrentUser() user: User,
    @Body() addFriendDto: AddFriendDto,
  ) {
    return this.friendsService.sendFriendRequest(user.id, addFriendDto);
  }

  @Get('requests')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách lời mời kết bạn' })
  async getFriendRequests(
    @CurrentUser() user: User,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.friendsService.getFriendRequests(user.id, page, limit);
  }

  @Post('requests/:id/accept')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Chấp nhận lời mời kết bạn' })
  async acceptFriendRequest(
    @CurrentUser() user: User,
    @Param('id') requestId: string,
  ) {
    return this.friendsService.acceptFriendRequest(user.id, requestId);
  }

  @Delete('requests/:id')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Từ chối/Xoá lời mời kết bạn' })
  async rejectFriendRequest(
    @CurrentUser() user: User,
    @Param('id') requestId: string,
  ) {
    return this.friendsService.rejectFriendRequest(user.id, requestId);
  }

  @Delete(':id')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá bạn bè' })
  async removeFriend(
    @CurrentUser() user: User,
    @Param('id') friendId: string,
  ) {
    return this.friendsService.removeFriend(user.id, friendId);
  }

  @Get('suggestions')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Gợi ý kết bạn' })
  async getFriendSuggestions(
    @CurrentUser() user: User,
    @Query('limit') limit = 10,
  ) {
    return this.friendsService.getFriendSuggestions(user.id, limit);
  }
}

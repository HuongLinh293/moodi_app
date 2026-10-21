import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  ForbiddenException,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdateAvatarDto } from './dto/update-avatar.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from './entities/user.entity';

// Ứng dụng sức khỏe tinh thần: không cho khách duyệt hồ sơ người dùng.
@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Hồ sơ của tôi' })
  async me(@CurrentUser() user: User) {
    return this.usersService.findById(user.id, user.id);
  }

  @Get('search/:query')
  @ApiOperation({ summary: 'Tìm kiếm người dùng theo username/tên hiển thị' })
  async search(@Param('query') query: string, @Query('limit') limit?: string) {
    return this.usersService.search(query, limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Lấy hồ sơ người dùng' })
  async findById(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.usersService.findById(id, user.id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Cập nhật hồ sơ' })
  async updateProfile(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateProfileDto: UpdateProfileDto,
    @CurrentUser() user: User,
  ) {
    this.assertSelf(user, id);
    return this.usersService.updateProfile(id, updateProfileDto);
  }

  @Patch(':id/avatar')
  @ApiOperation({ summary: 'Cập nhật ảnh đại diện (id file public của chính mình)' })
  async updateAvatar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdateAvatarDto,
    @CurrentUser() user: User,
  ) {
    this.assertSelf(user, id);
    return this.usersService.updateAvatar(id, body.avatar);
  }

  @Get(':id/stats')
  @ApiOperation({ summary: 'Thống kê người dùng' })
  async getStats(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.getStats(id);
  }

  private assertSelf(user: User, id: string) {
    if (user.id !== id) {
      throw new ForbiddenException('Bạn không có quyền sửa hồ sơ này');
    }
  }
}

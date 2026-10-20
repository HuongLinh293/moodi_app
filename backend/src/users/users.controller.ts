import {
  Controller,
  Get,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from './entities/user.entity';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get(':id')
  @ApiOperation({ summary: 'Lấy hồ sơ người dùng' })
  async findById(@Param('id') id: string) {
    return this.usersService.findById(id);
  }

  @Get('search/:query')
  @ApiOperation({ summary: 'Tìm kiếm người dùng' })
  async search(@Param('query') query: string, @Query('limit') limit = 10) {
    return this.usersService.search(query, limit);
  }

  @Patch(':id')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Cập nhật hồ sơ' })
  async updateProfile(
    @Param('id') id: string,
    @Body() updateProfileDto: UpdateProfileDto,
    @CurrentUser() user: User,
  ) {
    // Chỉ user chính hoặc admin mới được sửa
    if (user.id !== id) {
      throw new Error('Bạn không có quyền sửa hồ sơ này');
    }
    return this.usersService.updateProfile(id, updateProfileDto);
  }

  @Patch(':id/avatar')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Cập nhật ảnh đại diện' })
  async updateAvatar(
    @Param('id') id: string,
    @Body() body: { avatar: string },
    @CurrentUser() user: User,
  ) {
    if (user.id !== id) {
      throw new Error('Bạn không có quyền sửa hồ sơ này');
    }
    return this.usersService.updateAvatar(id, body.avatar);
  }

  @Get(':id/stats')
  @ApiOperation({ summary: 'Thống kê người dùng' })
  async getStats(@Param('id') id: string) {
    return this.usersService.getStats(id);
  }
}

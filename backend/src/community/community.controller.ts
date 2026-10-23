import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CommunityService } from './community.service';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

// Một cổng duy nhất giống callable `community` cũ: payload được kiểm tra theo
// danh sách trường cho phép của từng action trong CommunityService.
@ApiTags('community')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('community')
export class CommunityController {
  constructor(private communityService: CommunityService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Thực hiện một action Cộng đồng ({action, ...})' })
  async handle(@CurrentUser() user: User, @Body() body: unknown) {
    return this.communityService.handle(user, body);
  }
}

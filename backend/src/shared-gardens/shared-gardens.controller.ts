import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SharedGardensService } from './shared-gardens.service';
import {
  CreateGardenDto,
  InteractMomentDto,
  JoinGardenDto,
  PlantEntryDto,
} from './dto/shared-garden.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ClientIdPipe } from '../common/pipes/client-id.pipe';
import { User } from '../users/entities/user.entity';

@ApiTags('shared-gardens')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('shared-gardens')
export class SharedGardensController {
  constructor(private sharedGardensService: SharedGardensService) {}

  @Post('create')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Tạo vườn chung (trả vườn hiện có nếu đã là thành viên)' })
  async create(@CurrentUser() user: User, @Body() dto: CreateGardenDto) {
    return this.sharedGardensService.create(user, dto);
  }

  @Post('join')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Vào vườn bằng mã mời' })
  async join(@CurrentUser() user: User, @Body() dto: JoinGardenDto) {
    return this.sharedGardensService.join(user, dto);
  }

  @Get('user-garden')
  @ApiOperation({ summary: 'Vườn chung hiện tại của tôi ({} nếu chưa có)' })
  async findUserGarden(@CurrentUser() user: User) {
    return this.sharedGardensService.findUserGarden(user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết vườn (chỉ thành viên)' })
  async findById(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.sharedGardensService.findById(user, id);
  }

  @Get(':id/moments')
  @ApiOperation({ summary: 'Các bông hoa trong vườn (chỉ thành viên)' })
  async findMoments(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.sharedGardensService.findMoments(user, id);
  }

  @Post(':id/plant')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Trồng một ghi chép của tôi vào vườn' })
  async plant(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PlantEntryDto,
  ) {
    return this.sharedGardensService.plant(user, id, dto);
  }

  @Delete(':id/my-moments')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Gỡ mọi bông hoa tôi đã trồng' })
  async removeMyMoments(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    await this.sharedGardensService.removeMyMoments(user, id);
  }

  @Delete(':id/moments/:momentId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Gỡ một bông hoa (chỉ người trồng)' })
  async removeMoment(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('momentId', ClientIdPipe) momentId: string,
  ) {
    await this.sharedGardensService.removeMoment(user, id, momentId);
  }

  @Post(':id/moments/:momentId/interact')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Tưới nước hoặc gửi nắng (mỗi người một lần mỗi loại)' })
  async interact(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('momentId', ClientIdPipe) momentId: string,
    @Body() dto: InteractMomentDto,
  ) {
    return this.sharedGardensService.interact(user, id, momentId, dto.isWater);
  }

  @Post(':id/leave')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Rời vườn (vườn bị xoá khi không còn ai)' })
  async leave(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    await this.sharedGardensService.leave(user, id);
  }

  @Post(':id/refresh-invite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Tạo mã mời mới, vô hiệu mã cũ' })
  async refreshInvite(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.sharedGardensService.refreshInvite(user, id);
  }
}

import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { EntriesService } from './entries.service';
import { SaveEntryDto } from './dto/save-entry.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ClientIdPipe } from '../common/pipes/client-id.pipe';
import { User } from '../users/entities/user.entity';

// Mọi truy vấn chỉ trên dữ liệu của user trong JWT; tham số userId từ client bị bỏ qua.
@ApiTags('entries')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('entries')
export class EntriesController {
  constructor(private entriesService: EntriesService) {}

  @Get()
  @ApiOperation({ summary: 'Danh sách ghi chép của tôi' })
  async findAll(@CurrentUser() user: User) {
    return this.entriesService.findAll(user);
  }

  @Get('search')
  @ApiOperation({ summary: 'Tìm ghi chép theo cảm xúc/khoảng thời gian' })
  async search(
    @CurrentUser() user: User,
    @Query('emotionKey') emotionKey?: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.entriesService.search(user, emotionKey, startDate, endDate);
  }

  @Get('date/:date')
  @ApiOperation({ summary: 'Ghi chép trong một ngày (YYYY-MM-DD, UTC)' })
  async findForDate(@CurrentUser() user: User, @Param('date') date: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      throw new BadRequestException('Ngày không hợp lệ');
    }
    return this.entriesService.findForDate(user, date);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết ghi chép' })
  async findById(@CurrentUser() user: User, @Param('id', ClientIdPipe) id: string) {
    return this.entriesService.findById(user, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Tạo ghi chép' })
  async create(@CurrentUser() user: User, @Body() dto: SaveEntryDto) {
    return this.entriesService.save(user, dto);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Tạo hoặc cập nhật ghi chép theo id' })
  async upsert(
    @CurrentUser() user: User,
    @Param('id', ClientIdPipe) id: string,
    @Body() dto: SaveEntryDto,
  ) {
    return this.entriesService.save(user, dto, id);
  }

  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá toàn bộ ghi chép (cần header X-Delete-All: true)' })
  async deleteAll(
    @CurrentUser() user: User,
    @Headers('x-delete-all') confirm?: string,
  ) {
    if (confirm !== 'true') {
      throw new BadRequestException('Thiếu xác nhận X-Delete-All');
    }
    await this.entriesService.deleteAll(user);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá ghi chép' })
  async delete(@CurrentUser() user: User, @Param('id', ClientIdPipe) id: string) {
    await this.entriesService.delete(user, id);
  }
}

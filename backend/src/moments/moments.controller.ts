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
  ParseIntPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { MomentsService } from './moments.service';
import { SaveMomentDto } from './dto/save-moment.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ClientIdPipe } from '../common/pipes/client-id.pipe';
import { User } from '../users/entities/user.entity';

// Mọi truy vấn chỉ trên dữ liệu của user trong JWT; tham số userId từ client bị bỏ qua.
@ApiTags('moments')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('moments')
export class MomentsController {
  constructor(private momentsService: MomentsService) {}

  @Get()
  @ApiOperation({ summary: 'Danh sách khoảnh khắc trong vườn của tôi' })
  async findAll(@CurrentUser() user: User) {
    return this.momentsService.findAll(user);
  }

  @Get('month/:monthKey')
  @ApiOperation({ summary: 'Khoảnh khắc theo tháng (YYYY-MM)' })
  async findForMonth(@CurrentUser() user: User, @Param('monthKey') monthKey: string) {
    if (!/^\d{4}-\d{2}$/.test(monthKey)) {
      throw new BadRequestException('Tháng không hợp lệ');
    }
    return this.momentsService.findAll(user, { monthKey });
  }

  @Get('bed/:bedIndex')
  @ApiOperation({ summary: 'Khoảnh khắc theo luống' })
  async findForBed(
    @CurrentUser() user: User,
    @Param('bedIndex', ParseIntPipe) bedIndex: number,
  ) {
    return this.momentsService.findAll(user, { bedIndex });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết khoảnh khắc' })
  async findById(@CurrentUser() user: User, @Param('id', ClientIdPipe) id: string) {
    return this.momentsService.findById(user, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Trồng khoảnh khắc' })
  async create(@CurrentUser() user: User, @Body() dto: SaveMomentDto) {
    return this.momentsService.save(user, dto);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Tạo hoặc cập nhật khoảnh khắc theo id' })
  async upsert(
    @CurrentUser() user: User,
    @Param('id', ClientIdPipe) id: string,
    @Body() dto: SaveMomentDto,
  ) {
    return this.momentsService.save(user, dto, id);
  }

  @Delete()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá toàn bộ vườn (cần header X-Delete-All: true)' })
  async deleteAll(
    @CurrentUser() user: User,
    @Headers('x-delete-all') confirm?: string,
  ) {
    if (confirm !== 'true') {
      throw new BadRequestException('Thiếu xác nhận X-Delete-All');
    }
    await this.momentsService.deleteAll(user);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá khoảnh khắc' })
  async delete(@CurrentUser() user: User, @Param('id', ClientIdPipe) id: string) {
    await this.momentsService.delete(user, id);
  }
}

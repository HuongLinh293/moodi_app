import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { StorageService } from './storage.service';
import { UploadFileDto } from './dto/upload-file.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('storage')
@ApiBearerAuth()
@Controller('storage')
export class StorageController {
  constructor(private storageService: StorageService) {}

  @Post('upload')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Tải lên file' })
  async uploadFile(
    @CurrentUser() user: User,
    @Body() uploadFileDto: UploadFileDto,
  ) {
    return this.storageService.uploadFile(user.id, uploadFileDto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết file' })
  async getFile(
    @Param('id') id: string,
    @CurrentUser() user?: User,
  ) {
    return this.storageService.getFile(id, user?.id);
  }

  @Get(':id/content')
  @ApiOperation({ summary: 'Tải xuống file (base64)' })
  async getFileContent(
    @Param('id') id: string,
    @CurrentUser() user?: User,
  ) {
    return this.storageService.getFileContent(id, user?.id);
  }

  @Delete(':id')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xóa file' })
  async deleteFile(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.storageService.deleteFile(id, user.id);
  }

  @Get()
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách file của người dùng' })
  async getUserFiles(
    @CurrentUser() user: User,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.storageService.getUserFiles(user.id, page, limit);
  }

  @Get('related/:entityType/:entityId')
  @ApiOperation({ summary: 'Danh sách file liên quan' })
  async getFilesByRelatedEntity(
    @Param('entityType') entityType: string,
    @Param('entityId') entityId: string,
    @CurrentUser() user?: User,
  ) {
    return this.storageService.getFilesByRelatedEntity(
      entityType,
      entityId,
      user?.id,
    );
  }
}

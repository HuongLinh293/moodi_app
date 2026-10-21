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
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { StorageService } from './storage.service';
import { UploadFileDto } from './dto/upload-file.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { OptionalJwtGuard } from '../auth/guards/optional-jwt.guard';
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
  @UseGuards(OptionalJwtGuard)
  @ApiOperation({ summary: 'Chi tiết file' })
  async getFile(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user?: User,
  ) {
    return this.storageService.getFile(id, user?.id);
  }

  @Get(':id/content')
  @UseGuards(OptionalJwtGuard)
  @ApiOperation({ summary: 'Tải xuống file (base64)' })
  async getFileContent(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user?: User,
  ) {
    return this.storageService.getFileContent(id, user?.id);
  }

  @Delete(':id')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xóa file' })
  async deleteFile(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    return this.storageService.deleteFile(id, user.id);
  }

  @Get()
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách file của người dùng' })
  async getUserFiles(
    @CurrentUser() user: User,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.storageService.getUserFiles(user.id, page, limit);
  }

  @Get('related/:entityType/:entityId')
  @UseGuards(OptionalJwtGuard)
  @ApiOperation({ summary: 'Danh sách file liên quan' })
  async getFilesByRelatedEntity(
    @Param('entityType') entityType: string,
    @Param('entityId', ParseUUIDPipe) entityId: string,
    @CurrentUser() user?: User,
  ) {
    return this.storageService.getFilesByRelatedEntity(
      entityType,
      entityId,
      user?.id,
    );
  }
}

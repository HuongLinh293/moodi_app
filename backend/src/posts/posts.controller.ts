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
import { PostsService } from './posts.service';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('posts')
@Controller('posts')
export class PostsController {
  constructor(private postsService: PostsService) {}

  @Post()
  @UseGuards(JwtGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Tạo bài viết' })
  async create(
    @Body() createPostDto: CreatePostDto,
    @CurrentUser() user: User,
  ) {
    return this.postsService.create(createPostDto, user);
  }

  @Get()
  @ApiOperation({ summary: 'Danh sách bài viết' })
  async findAll(
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.postsService.findAll(page, limit);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết bài viết' })
  async findById(@Param('id') id: string) {
    return this.postsService.findById(id);
  }

  @Patch(':id')
  @UseGuards(JwtGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Sửa bài viết' })
  async update(
    @Param('id') id: string,
    @Body() updatePostDto: UpdatePostDto,
    @CurrentUser() user: User,
  ) {
    return this.postsService.update(id, updatePostDto, user);
  }

  @Delete(':id')
  @UseGuards(JwtGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá bài viết' })
  async delete(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.postsService.delete(id, user);
  }

  @Post(':id/like')
  @UseGuards(JwtGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Thích bài viết' })
  async like(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.postsService.like(id, user);
  }

  @Delete(':id/like')
  @UseGuards(JwtGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Bỏ thích bài viết' })
  async unlike(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.postsService.unlike(id, user);
  }
}

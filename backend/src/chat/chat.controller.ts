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
import { ChatService } from './chat.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('chat')
@ApiBearerAuth()
@Controller('chat')
export class ChatController {
  constructor(private chatService: ChatService) {}

  @Get('conversations')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách cuộc trò chuyện' })
  async getConversations(
    @CurrentUser() user: User,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.chatService.getConversations(user.id, page, limit);
  }

  @Post('conversations')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Tạo cuộc trò chuyện' })
  async createConversation(
    @CurrentUser() user: User,
    @Body() createConversationDto: CreateConversationDto,
  ) {
    return this.chatService.createConversation(user.id, createConversationDto);
  }

  @Get('conversations/:id')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Chi tiết cuộc trò chuyện' })
  async getConversationById(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.chatService.getConversationById(id, user.id);
  }

  @Delete('conversations/:id')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xoá cuộc trò chuyện' })
  async deleteConversation(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return this.chatService.deleteConversation(id, user.id);
  }

  @Get('conversations/:id/messages')
  @UseGuards(JwtGuard)
  @ApiOperation({ summary: 'Danh sách tin nhắn' })
  async getMessages(
    @Param('id') id: string,
    @CurrentUser() user: User,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.chatService.getMessages(id, user.id, page, limit);
  }

  @Post('conversations/:id/messages')
  @UseGuards(JwtGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Gửi tin nhắn' })
  async sendMessage(
    @Param('id') id: string,
    @CurrentUser() user: User,
    @Body() sendMessageDto: SendMessageDto,
  ) {
    return this.chatService.sendMessage(id, user.id, sendMessageDto);
  }
}

import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Conversation } from './entities/conversation.entity';
import { ConversationParticipant } from './entities/conversation-participant.entity';
import { Message } from './entities/message.entity';
import { User } from '../users/entities/user.entity';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Conversation)
    private conversationsRepository: Repository<Conversation>,
    @InjectRepository(ConversationParticipant)
    private participantsRepository: Repository<ConversationParticipant>,
    @InjectRepository(Message)
    private messagesRepository: Repository<Message>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  // Get conversations for a user
  async getConversations(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [participants, total] = await this.participantsRepository.findAndCount({
      where: { userId },
      relations: ['conversation', 'conversation.messages'],
      skip,
      take: limit,
      order: { joinedAt: 'DESC' },
    });

    // Get last message for each conversation
    const conversations = await Promise.all(
      participants.map(async (p) => {
        const lastMessage = await this.messagesRepository.findOne({
          where: { conversationId: p.conversationId },
          order: { createdAt: 'DESC' },
          relations: ['sender'],
        });

        return {
          ...this.formatConversationResponse(p.conversation),
          lastMessage: lastMessage ? this.formatMessageResponse(lastMessage) : null,
          joinedAt: p.joinedAt,
        };
      }),
    );

    return {
      data: conversations,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Create a new conversation
  async createConversation(userId: string, createConversationDto: CreateConversationDto) {
    // Validate participant IDs
    const participantIds = Array.from(
      new Set([userId, ...createConversationDto.participantIds]),
    );

    if (participantIds.length < 2) {
      throw new BadRequestException('Cần ít nhất 2 người tham gia');
    }

    // Check if users exist
    const users = await this.usersRepository.find({
      where: { id: In(participantIds) },
    });

    if (users.length !== participantIds.length) {
      throw new BadRequestException('Một hoặc nhiều người dùng không tồn tại');
    }

    // For direct messages, check if conversation already exists
    if (createConversationDto.type === 'direct' && participantIds.length === 2) {
      const existing = await this.findDirectConversation(
        participantIds[0],
        participantIds[1],
      );
      if (existing) {
        return {
          message: 'Cuộc trò chuyện đã tồn tại',
          data: this.formatConversationResponse(existing),
        };
      }
    }

    // Create conversation
    const conversation = this.conversationsRepository.create({
      type: createConversationDto.type,
      name: createConversationDto.name,
    });

    const saved = await this.conversationsRepository.save(conversation);

    // Add participants
    const participants = participantIds.map((pId) =>
      this.participantsRepository.create({
        conversationId: saved.id,
        userId: pId,
      }),
    );

    await this.participantsRepository.save(participants);

    return {
      message: 'Cuộc trò chuyện được tạo thành công',
      data: this.formatConversationResponse(saved),
    };
  }

  // Get messages in conversation
  async getMessages(conversationId: string, userId: string, page = 1, limit = 20) {
    // Check if user is participant
    const isParticipant = await this.participantsRepository.findOne({
      where: { conversationId, userId },
    });

    if (!isParticipant) {
      throw new ForbiddenException(
        'Bạn không có quyền xem tin nhắn trong cuộc trò chuyện này',
      );
    }

    const skip = (page - 1) * limit;

    const [messages, total] = await this.messagesRepository.findAndCount({
      where: { conversationId },
      relations: ['sender'],
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data: messages.reverse().map((m) => this.formatMessageResponse(m)),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  // Send message
  async sendMessage(
    conversationId: string,
    userId: string,
    sendMessageDto: SendMessageDto,
  ) {
    // Check if conversation exists
    const conversation = await this.conversationsRepository.findOne({
      where: { id: conversationId },
    });

    if (!conversation) {
      throw new NotFoundException('Cuộc trò chuyện không tồn tại');
    }

    // Check if user is participant
    const isParticipant = await this.participantsRepository.findOne({
      where: { conversationId, userId },
    });

    if (!isParticipant) {
      throw new ForbiddenException(
        'Bạn không có quyền gửi tin nhắn trong cuộc trò chuyện này',
      );
    }

    // Create message
    const message = this.messagesRepository.create({
      conversationId,
      senderId: userId,
      content: sendMessageDto.content,
      imageUrls: sendMessageDto.imageUrls,
    });

    const saved = await this.messagesRepository.save(message);

    const savedWithSender = await this.messagesRepository.findOne({
      where: { id: saved.id },
      relations: ['sender'],
    });

    if (!savedWithSender) {
      throw new Error('Failed to save message');
    }

    return {
      message: 'Tin nhắn được gửi thành công',
      data: this.formatMessageResponse(savedWithSender),
    };
  }

  // Delete conversation
  async deleteConversation(conversationId: string, userId: string) {
    const conversation = await this.conversationsRepository.findOne({
      where: { id: conversationId },
    });

    if (!conversation) {
      throw new NotFoundException('Cuộc trò chuyện không tồn tại');
    }

    // Check if user is participant
    const participant = await this.participantsRepository.findOne({
      where: { conversationId, userId },
    });

    if (!participant) {
      throw new ForbiddenException(
        'Bạn không có quyền xoá cuộc trò chuyện này',
      );
    }

    // Remove user from conversation
    await this.participantsRepository.delete(participant.id);

    // If no participants left, delete conversation
    const remainingParticipants = await this.participantsRepository.count({
      where: { conversationId },
    });

    if (remainingParticipants === 0) {
      await this.conversationsRepository.delete(conversationId);
    }

    return {
      message: 'Cuộc trò chuyện được xoá thành công',
    };
  }

  // Get conversation details
  async getConversationById(conversationId: string, userId: string) {
    const conversation = await this.conversationsRepository.findOne({
      where: { id: conversationId },
    });

    if (!conversation) {
      throw new NotFoundException('Cuộc trò chuyện không tồn tại');
    }

    // Check if user is participant
    const isParticipant = await this.participantsRepository.findOne({
      where: { conversationId, userId },
    });

    if (!isParticipant) {
      throw new ForbiddenException(
        'Bạn không có quyền xem cuộc trò chuyện này',
      );
    }

    // Get participants
    const participants = await this.participantsRepository.find({
      where: { conversationId },
      relations: ['user'],
    });

    return {
      ...this.formatConversationResponse(conversation),
      participants: participants.map((p) => ({
        id: p.user.id,
        username: p.user.username,
        displayName: p.user.displayName,
        avatar: p.user.avatar,
      })),
    };
  }

  // Helper methods
  private async findDirectConversation(userId1: string, userId2: string) {
    const conversation = await this.conversationsRepository
      .createQueryBuilder('c')
      .innerJoinAndSelect(
        'c.participants',
        'p1',
        'p1.conversationId = c.id AND p1.userId = :userId1',
        { userId1 },
      )
      .innerJoin(
        'c.participants',
        'p2',
        'p2.conversationId = c.id AND p2.userId = :userId2',
        { userId2 },
      )
      .where('c.type = :type', { type: 'direct' })
      .getOne();

    return conversation;
  }

  private formatConversationResponse(conversation: Conversation) {
    return {
      id: conversation.id,
      type: conversation.type,
      name: conversation.name,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  private formatMessageResponse(message: Message) {
    return {
      id: message.id,
      conversationId: message.conversationId,
      sender: {
        id: message.sender.id,
        username: message.sender.username,
        displayName: message.sender.displayName,
        avatar: message.sender.avatar,
      },
      content: message.content,
      imageUrls: message.imageUrls,
      isEdited: message.isEdited,
      createdAt: message.createdAt,
      editedAt: message.editedAt,
    };
  }
}

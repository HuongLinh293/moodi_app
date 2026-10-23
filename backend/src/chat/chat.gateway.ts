import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server } from 'socket.io';
import { UsePipes, ValidationPipe } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import { WsOnlineStatusDto, WsSendMessageDto, WsTypingDto } from './dto/ws-events.dto';
import { JwtService } from '@nestjs/jwt';
import { ChatService } from './chat.service';

interface AuthenticatedSocket {
  userId?: string;
  id: string;
  handshake: any;
  disconnect: () => void;
  join: (room: string) => void;
}

@WebSocketGateway({
  cors: {
    origin: (process.env.CORS_ORIGIN || 'http://localhost:3000').split(','),
    credentials: true,
  },
})
// HTTP ValidationPipe toàn cục không áp dụng cho WebSocket; cần khai báo riêng.
@UsePipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    exceptionFactory: () => new WsException('Dữ liệu không hợp lệ'),
  }),
)
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private userSockets: Map<string, Set<string>> = new Map();

  constructor(
    private jwtService: JwtService,
    private chatService: ChatService,
  ) {}

  // Connection handler
  async handleConnection(socket: any) {
    try {
      // Get JWT token from handshake
      const token = socket.handshake.auth.token;
      if (!token) {
        socket.disconnect();
        return;
      }

      // Verify JWT
      const payload = this.jwtService.verify(token);
      socket.userId = payload.sub;

      // Add socket to user's sockets
      if (!this.userSockets.has(socket.userId)) {
        this.userSockets.set(socket.userId, new Set());
      }
      this.userSockets.get(socket.userId)!.add(socket.id);

      // Join user room
      socket.join(`user:${socket.userId}`);

      console.log(`User ${socket.userId} connected`);
    } catch (error) {
      console.warn('WebSocket connection rejected');
      socket.disconnect();
    }
  }

  // Disconnect handler
  handleDisconnect(socket: any) {
    if (socket.userId) {
      const userSockets = this.userSockets.get(socket.userId);
      if (userSockets) {
        userSockets.delete(socket.id);
        if (userSockets.size === 0) {
          this.userSockets.delete(socket.userId);
        }
      }
      console.log(`User ${socket.userId} disconnected`);
    }
  }

  // Send message event
  @SubscribeMessage('send_message')
  async handleSendMessage(
    @ConnectedSocket() socket: any,
    @MessageBody() data: WsSendMessageDto,
  ) {
    try {
      if (!socket.userId) {
        return { error: 'Không xác thực' };
      }

      // Save message to database
      const messageResult = await this.chatService.sendMessage(
        data.conversationId,
        socket.userId,
        {
          content: data.content,
          imageUrls: data.imageUrls,
        },
      );

      // Get conversation participants
      const conversation = await this.chatService.getConversationById(
        data.conversationId,
        socket.userId,
      );

      // Broadcast message to all participants
      conversation.participants.forEach((participant) => {
        this.server.to(`user:${participant.id}`).emit('message_received', {
          conversationId: data.conversationId,
          message: messageResult.data,
        });
      });

      return { success: true, data: messageResult.data };
    } catch (error) {
      console.error('Error sending message:', error);
      return { error: (error as any)?.message || 'Unknown error' };
    }
  }

  // Typing indicator event
  @SubscribeMessage('typing')
  async handleTyping(
    @ConnectedSocket() socket: any,
    @MessageBody() data: WsTypingDto,
  ) {
    try {
      if (!socket.userId) {
        return { error: 'Không xác thực' };
      }

      // Get conversation to find participants
      const conversation = await this.chatService.getConversationById(
        data.conversationId,
        socket.userId,
      );

      // Send typing status to other participants
      conversation.participants.forEach((participant) => {
        if (participant.id !== socket.userId) {
          this.server.to(`user:${participant.id}`).emit('user_typing', {
            conversationId: data.conversationId,
            userId: socket.userId,
            isTyping: data.isTyping,
          });
        }
      });

      return { success: true };
    } catch (error) {
      console.error('Error handling typing:', error);
      return { error: (error as any)?.message || 'Unknown error' };
    }
  }

  // Online status event
  @SubscribeMessage('online_status')
  async handleOnlineStatus(
    @ConnectedSocket() socket: any,
    @MessageBody() data: WsOnlineStatusDto,
  ) {
    try {
      if (!socket.userId) {
        return { error: 'Không xác thực' };
      }

      // Chỉ báo trạng thái cho bạn bè, không phát cho toàn bộ người dùng.
      const friendIds = await this.chatService.friendIds(socket.userId);
      for (const friendId of friendIds) {
        this.server.to(`user:${friendId}`).emit('user_online_status', {
          userId: socket.userId,
          isOnline: data.isOnline,
        });
      }

      return { success: true };
    } catch (error) {
      console.error('Error handling online status:', error);
      return { error: (error as any)?.message || 'Unknown error' };
    }
  }

  // Utility method to emit to conversation participants
  async emitToConversation(
    conversationId: string,
    event: string,
    data: any,
  ) {
    try {
      const room = `conversation:${conversationId}`;
      this.server.to(room).emit(event, data);
    } catch (error) {
      console.error('Error emitting to conversation:', error);
    }
  }

  // Utility method to emit to user
  emitToUser(userId: string, event: string, data: any) {
    this.server.to(`user:${userId}`).emit(event, data);
  }
}

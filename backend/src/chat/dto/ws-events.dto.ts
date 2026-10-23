import { IsBoolean, IsUUID } from 'class-validator';
import { SendMessageDto } from './send-message.dto';

export class WsSendMessageDto extends SendMessageDto {
  @IsUUID()
  conversationId: string;
}

export class WsTypingDto {
  @IsUUID()
  conversationId: string;

  @IsBoolean()
  isTyping: boolean;
}

export class WsOnlineStatusDto {
  @IsBoolean()
  isOnline: boolean;
}

import { ExecutionContext, Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

// ThrottlerGuard đọc req/res HTTP; bỏ qua ngữ cảnh WebSocket thay vì làm hỏng gateway.
@Injectable()
export class HttpThrottlerGuard extends ThrottlerGuard {
  protected async shouldSkip(context: ExecutionContext): Promise<boolean> {
    return context.getType() !== 'http' || super.shouldSkip(context);
  }
}

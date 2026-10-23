import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

// Cho phép khách, nhưng nếu có Bearer token hợp lệ thì gắn request.user.
// Token sai/hết hạn bị từ chối thay vì âm thầm coi như khách.
@Injectable()
export class OptionalJwtGuard extends AuthGuard('jwt') {
  canActivate(context: any) {
    const request = context.switchToHttp().getRequest();
    if (!request.headers?.authorization) return true;
    return super.canActivate(context);
  }
}

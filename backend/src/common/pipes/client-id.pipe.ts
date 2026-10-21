import { BadRequestException, Injectable, PipeTransform } from '@nestjs/common';

// Id do client sinh (vd: entry-1729500000000, garden-entry-..., <uuid>_entry-...).
const CLIENT_ID = /^[A-Za-z0-9_-]{1,160}$/;

@Injectable()
export class ClientIdPipe implements PipeTransform<string, string> {
  transform(value: string): string {
    if (typeof value !== 'string' || !CLIENT_ID.test(value)) {
      throw new BadRequestException('Mã định danh không hợp lệ');
    }
    return value;
  }
}

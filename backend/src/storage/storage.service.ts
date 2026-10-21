import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { StorageFile } from './entities/storage-file.entity';
import { User } from '../users/entities/user.entity';
import { UploadFileDto } from './dto/upload-file.dto';
import { pageParams } from '../common/pagination';

// Chỉ nhận định dạng có chữ ký nhận diện được; mimeType do client khai báo
// phải khớp với nội dung thật.
const SIGNATURES: Record<string, (b: Buffer) => boolean> = {
  'image/jpeg': (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,
  'image/png': (b) =>
    b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
  'image/gif': (b) => b.subarray(0, 6).toString('ascii').startsWith('GIF8'),
  'image/webp': (b) =>
    b.subarray(0, 4).toString('ascii') === 'RIFF' && b.subarray(8, 12).toString('ascii') === 'WEBP',
  'application/pdf': (b) => b.subarray(0, 5).toString('ascii') === '%PDF-',
};
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

@Injectable()
export class StorageService {
  private uploadDir = path.resolve(process.env.UPLOAD_FOLDER || path.join(process.cwd(), 'uploads'));
  private maxSize = parseInt(process.env.MAX_FILE_SIZE || `${10 * 1024 * 1024}`, 10);

  constructor(
    @InjectRepository(StorageFile)
    private storageFilesRepository: Repository<StorageFile>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {
    // Ensure upload directory exists
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  // Upload file
  async uploadFile(userId: string, uploadFileDto: UploadFileDto) {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    if (!BASE64.test(uploadFileDto.fileContent)) {
      throw new BadRequestException('Nội dung file không hợp lệ');
    }
    const buffer = Buffer.from(uploadFileDto.fileContent, 'base64');
    if (buffer.length === 0 || buffer.length > this.maxSize) {
      throw new BadRequestException(
        `File trống hoặc quá lớn (tối đa ${Math.floor(this.maxSize / 1024 / 1024)}MB)`,
      );
    }

    const mimeType = uploadFileDto.mimeType;
    const matches = SIGNATURES[mimeType];
    if (!matches || !matches(buffer)) {
      throw new BadRequestException('Định dạng file không được hỗ trợ hoặc không khớp nội dung');
    }

    // Tên trên đĩa do server sinh; tên gốc chỉ lưu làm nhãn hiển thị.
    const diskName = randomUUID();
    try {
      fs.writeFileSync(path.join(this.uploadDir, diskName), buffer, { flag: 'wx' });
    } catch (error) {
      throw new BadRequestException('Lỗi khi lưu file');
    }

    const storageFile = this.storageFilesRepository.create({
      uploadedById: userId,
      filename: this.displayName(uploadFileDto.filename),
      filePath: `/uploads/${diskName}`,
      fileSize: buffer.length,
      mimeType,
      accessType: uploadFileDto.accessType || 'private',
      relatedEntityType: uploadFileDto.relatedEntityType,
      relatedEntityId: uploadFileDto.relatedEntityId,
    });

    const saved = await this.storageFilesRepository.save(storageFile);

    return {
      message: 'File được tải lên thành công',
      data: this.formatFileResponse(saved),
    };
  }

  // Get file by ID
  async getFile(id: string, userId?: string) {
    return this.formatFileResponse(await this.findAccessible(id, userId));
  }

  // Get file content (for download/display)
  async getFileContent(id: string, userId?: string) {
    const file = await this.findAccessible(id, userId);
    const filePath = this.diskPath(file);

    if (!fs.existsSync(filePath)) {
      throw new NotFoundException('File không tồn tại trên server');
    }

    const content = fs.readFileSync(filePath);
    return {
      content: content.toString('base64'),
      mimeType: file.mimeType,
      filename: file.filename,
    };
  }

  // Delete file
  async deleteFile(id: string, userId: string) {
    const file = await this.storageFilesRepository.findOne({
      where: { id },
    });

    if (!file) {
      throw new NotFoundException('File không tồn tại');
    }

    // Check permission
    if (file.uploadedById !== userId) {
      throw new ForbiddenException(
        'Bạn không có quyền xóa file này',
      );
    }

    const filePath = this.diskPath(file);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    // Delete from database
    await this.storageFilesRepository.delete(id);

    return {
      message: 'File được xóa thành công',
    };
  }

  // Get user's files
  async getUserFiles(userId: string, page?: unknown, limit?: unknown) {
    const params = pageParams(page, limit);

    const [files, total] = await this.storageFilesRepository.findAndCount({
      where: { uploadedById: userId },
      skip: params.skip,
      take: params.limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data: files.map((f) => this.formatFileResponse(f)),
      pagination: {
        page: params.page,
        limit: params.limit,
        total,
        pages: Math.ceil(total / params.limit),
      },
    };
  }

  // Get files for related entity
  async getFilesByRelatedEntity(
    relatedEntityType: string,
    relatedEntityId: string,
    userId?: string,
  ) {
    const files = await this.storageFilesRepository.find({
      where: {
        relatedEntityType,
        relatedEntityId,
      },
      order: { createdAt: 'DESC' },
      take: 50,
    });

    // Filter based on access permissions
    const filtered = files.filter((f) => {
      if (f.accessType === 'public') return true;
      if (f.uploadedById === userId) return true;
      return false;
    });

    return {
      data: filtered.map((f) => this.formatFileResponse(f)),
    };
  }

  private async findAccessible(id: string, userId?: string): Promise<StorageFile> {
    const file = await this.storageFilesRepository.findOne({ where: { id } });

    // Không phân biệt "không tồn tại" và "không có quyền" để tránh dò id file private.
    if (!file || (file.accessType === 'private' && file.uploadedById !== userId)) {
      throw new NotFoundException('File không tồn tại');
    }

    return file;
  }

  // Bản ghi cũ có thể chứa tên do client đặt; luôn ép đường dẫn nằm trong uploadDir.
  private diskPath(file: StorageFile): string {
    const resolved = path.resolve(this.uploadDir, path.basename(file.filePath));
    if (path.dirname(resolved) !== this.uploadDir) {
      throw new NotFoundException('File không tồn tại trên server');
    }
    return resolved;
  }

  private displayName(filename: string): string {
    const base = path.basename(filename.replace(/\\/g, '/'));
    const clean = base.replace(/[^\p{L}\p{N}._ -]/gu, '_').slice(0, 120);
    return clean || 'file';
  }

  // Helper methods
  private formatFileResponse(file: StorageFile) {
    return {
      id: file.id,
      filename: file.filename,
      contentUrl: `/api/storage/${file.id}/content`,
      fileSize: file.fileSize,
      mimeType: file.mimeType,
      accessType: file.accessType,
      uploadedById: file.uploadedById,
      relatedEntityType: file.relatedEntityType,
      relatedEntityId: file.relatedEntityId,
      createdAt: file.createdAt,
    };
  }
}

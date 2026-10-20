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
import { StorageFile } from './entities/storage-file.entity';
import { User } from '../users/entities/user.entity';
import { UploadFileDto } from './dto/upload-file.dto';

@Injectable()
export class StorageService {
  private uploadDir = path.join(process.cwd(), 'uploads');

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

    // Decode base64 content
    let buffer: Buffer;
    try {
      buffer = Buffer.from(uploadFileDto.fileContent, 'base64');
    } catch (error) {
      throw new BadRequestException('Nội dung file không hợp lệ');
    }

    // Validate file size (max 50MB)
    const maxSize = 50 * 1024 * 1024;
    if (buffer.length > maxSize) {
      throw new BadRequestException('File quá lớn, tối đa 50MB');
    }

    // Generate unique filename
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(7);
    const filename = `${timestamp}-${randomStr}-${uploadFileDto.filename}`;
    const filePath = path.join(this.uploadDir, filename);

    // Save file to disk
    try {
      fs.writeFileSync(filePath, buffer);
    } catch (error) {
      throw new BadRequestException('Lỗi khi lưu file');
    }

    // Create database record
    const storageFile = this.storageFilesRepository.create({
      uploadedById: userId,
      filename: uploadFileDto.filename,
      filePath: `/uploads/${filename}`,
      fileSize: buffer.length,
      mimeType: uploadFileDto.mimeType || 'application/octet-stream',
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
    const file = await this.storageFilesRepository.findOne({
      where: { id },
      relations: ['uploadedBy'],
    });

    if (!file) {
      throw new NotFoundException('File không tồn tại');
    }

    // Check access permission
    if (file.accessType === 'private' && file.uploadedById !== userId) {
      throw new ForbiddenException('Bạn không có quyền truy cập file này');
    }

    return this.formatFileResponse(file);
  }

  // Get file content (for download/display)
  async getFileContent(id: string, userId?: string) {
    const file = await this.getFile(id, userId);

    // Check if file exists on disk
    const filePath = path.join(process.cwd(), file.filePath);
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

    // Delete from disk
    const filePath = path.join(process.cwd(), file.filePath);
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
  async getUserFiles(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [files, total] = await this.storageFilesRepository.findAndCount({
      where: { uploadedById: userId },
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data: files.map((f) => this.formatFileResponse(f)),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
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

  // Helper methods
  private formatFileResponse(file: StorageFile) {
    return {
      id: file.id,
      filename: file.filename,
      filePath: file.filePath,
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

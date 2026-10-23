import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/api_config.dart';

/// Represents a stored file
class StorageFile {
  final String id;
  final String filename;
  final String filePath;
  final int fileSize;
  final String? mimeType;
  final String accessType; // public, private
  final String uploadedById;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime createdAt;

  StorageFile({
    required this.id,
    required this.filename,
    required this.filePath,
    required this.fileSize,
    this.mimeType,
    required this.accessType,
    required this.uploadedById,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.createdAt,
  });

  factory StorageFile.fromJson(Map<String, dynamic> json) {
    return StorageFile(
      id: json['id'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      // Server không lộ đường dẫn trên đĩa; chỉ trả URL đọc qua API có kiểm tra quyền.
      filePath: (json['contentUrl'] ?? json['filePath']) as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String?,
      accessType: json['accessType'] as String? ?? 'private',
      uploadedById: json['uploadedById'] as String? ?? '',
      relatedEntityType: json['relatedEntityType'] as String?,
      relatedEntityId: json['relatedEntityId'] as String?,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'filePath': filePath,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'accessType': accessType,
      'uploadedById': uploadedById,
      'relatedEntityType': relatedEntityType,
      'relatedEntityId': relatedEntityId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Paginated files response
class FilesPage {
  final List<StorageFile> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  FilesPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory FilesPage.fromJson(Map<String, dynamic> json) {
    return FilesPage(
      data: ((json['data'] as List?) ?? [])
          .map((f) => StorageFile.fromJson(f as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

class StorageRepository {
  final HttpClient _httpClient;

  StorageRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Upload file (from Uint8List or String path)
  Future<StorageFile?> uploadFile({
    required String filename,
    required String fileContent, // base64 encoded content
    // Bắt buộc: server đối chiếu với chữ ký (magic bytes) của nội dung.
    required String mimeType,
    String accessType = 'private',
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.uploadEndpoint,
        body: {
          'filename': filename,
          'fileContent': fileContent, // already base64 encoded
          'mimeType': mimeType,
          'accessType': accessType,
          'relatedEntityType': ?relatedEntityType,
          'relatedEntityId': ?relatedEntityId,
        },
      );

      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          return StorageFile.fromJson(response['data'] as Map<String, dynamic>);
        }
        return StorageFile.fromJson(response);
      }
    } catch (e) {
      debugPrint('StorageRepository: uploadFile error: $e');
      rethrow;
    }
    return null;
  }

  /// Get file metadata
  Future<StorageFile?> getFileById(String fileId) async {
    try {
      final response = await _httpClient.get(ApiConfig.storageFile(fileId));

      if (response is Map<String, dynamic>) {
        return StorageFile.fromJson(response);
      }
    } catch (e) {
      debugPrint('StorageRepository: getFileById error: $e');
    }
    return null;
  }

  /// Download file (returns base64 encoded content)
  Future<String?> downloadFile(String fileId) async {
    try {
      final response = await _httpClient.get(ApiConfig.downloadFile(fileId));

      if (response is Map<String, dynamic>) {
        return response['content'] as String?;
      }
    } catch (e) {
      debugPrint('StorageRepository: downloadFile error: $e');
    }
    return null;
  }

  /// Delete file
  Future<bool> deleteFile(String fileId) async {
    try {
      await _httpClient.delete(ApiConfig.storageFile(fileId));
      return true;
    } catch (e) {
      debugPrint('StorageRepository: deleteFile error: $e');
      return false;
    }
  }

  /// Get user's files
  Future<FilesPage?> getUserFiles({int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.storageEndpoint,
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      if (response is Map<String, dynamic>) {
        return FilesPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('StorageRepository: getUserFiles error: $e');
    }
    return null;
  }

  /// Get files for related entity (post, group, etc.)
  Future<List<StorageFile>> getFilesByEntity(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.filesByEntity(entityType, entityId),
      );

      if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List)
            .map((f) => StorageFile.fromJson(f as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return response
            .map((f) => StorageFile.fromJson(f as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('StorageRepository: getFilesByEntity error: $e');
    }
    return [];
  }
}

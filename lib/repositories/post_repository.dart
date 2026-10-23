import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/api_config.dart';
import 'user_repository.dart';

/// Represents a single post
class Post {
  final String id;
  final UserProfile author;
  final String content;
  final List<String>? imageUrls;
  final int likesCount;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrls,
    required this.likesCount,
    required this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String? ?? '',
      author: UserProfile.fromJson(
        json['author'] as Map<String, dynamic>? ?? {},
      ),
      content: json['content'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List?)?.cast<String>(),
      likesCount: json['likesCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author.toJson(),
      'content': content,
      'imageUrls': imageUrls,
      'likesCount': likesCount,
      'isLiked': isLiked,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Paginated posts response
class PostsPage {
  final List<Post> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  PostsPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PostsPage.fromJson(Map<String, dynamic> json) {
    return PostsPage(
      data: ((json['data'] as List?) ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

class PostRepository {
  final HttpClient _httpClient;

  PostRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Get paginated posts
  Future<PostsPage?> getPosts({int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.postsEndpoint,
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      if (response is Map<String, dynamic>) {
        return PostsPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('PostRepository: getPosts error: $e');
    }
    return null;
  }

  /// Get single post by ID
  Future<Post?> getPostById(String postId) async {
    try {
      final response = await _httpClient.get(ApiConfig.postById(postId));

      if (response is Map<String, dynamic>) {
        return Post.fromJson(response);
      }
    } catch (e) {
      debugPrint('PostRepository: getPostById error: $e');
    }
    return null;
  }

  /// Create a new post
  Future<Post?> createPost({
    required String content,
    List<String>? imageUrls,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.postsEndpoint,
        body: {'content': content, 'imageUrls': ?imageUrls},
      );

      if (response is Map<String, dynamic>) {
        // Handle nested response structure
        if (response['data'] is Map<String, dynamic>) {
          return Post.fromJson(response['data'] as Map<String, dynamic>);
        }
        return Post.fromJson(response);
      }
    } catch (e) {
      debugPrint('PostRepository: createPost error: $e');
      rethrow;
    }
    return null;
  }

  /// Update a post
  Future<Post?> updatePost({
    required String postId,
    required String content,
    List<String>? imageUrls,
  }) async {
    try {
      final response = await _httpClient.patch(
        ApiConfig.postById(postId),
        body: {'content': content, 'imageUrls': ?imageUrls},
      );

      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          return Post.fromJson(response['data'] as Map<String, dynamic>);
        }
        return Post.fromJson(response);
      }
    } catch (e) {
      debugPrint('PostRepository: updatePost error: $e');
      rethrow;
    }
    return null;
  }

  /// Delete a post
  Future<bool> deletePost(String postId) async {
    try {
      await _httpClient.delete(ApiConfig.postById(postId));
      return true;
    } catch (e) {
      debugPrint('PostRepository: deletePost error: $e');
      return false;
    }
  }

  /// Like a post
  Future<bool> likePost(String postId) async {
    try {
      await _httpClient.post(ApiConfig.likePost(postId), body: {});
      return true;
    } catch (e) {
      debugPrint('PostRepository: likePost error: $e');
      return false;
    }
  }

  /// Unlike a post
  Future<bool> unlikePost(String postId) async {
    try {
      await _httpClient.delete(ApiConfig.likePost(postId));
      return true;
    } catch (e) {
      debugPrint('PostRepository: unlikePost error: $e');
      return false;
    }
  }
}

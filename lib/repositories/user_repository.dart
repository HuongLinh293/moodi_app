import 'package:flutter/foundation.dart';
import '../core/http_client.dart';
import '../core/api_config.dart';

/// Represents a user profile
class UserProfile {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatar;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatar,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      bio: json['bio'] as String?,
      avatar: json['avatar'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
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
      'email': email,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatar': avatar,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Represents user statistics
class UserStats {
  final String id;
  final String username;
  final int postsCount;
  final int friendsCount;
  final DateTime joinedAt;

  UserStats({
    required this.id,
    required this.username,
    required this.postsCount,
    required this.friendsCount,
    required this.joinedAt,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      postsCount: json['postsCount'] as int? ?? 0,
      friendsCount: json['friendsCount'] as int? ?? 0,
      joinedAt: DateTime.parse(
        json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class UserRepository {
  final HttpClient _httpClient;

  UserRepository({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Get user profile by ID
  Future<UserProfile?> getUserById(String userId) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.userById(userId),
      );

      if (response is Map<String, dynamic>) {
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('UserRepository: getUserById error: $e');
    }
    return null;
  }

  /// Search users by query
  Future<List<UserProfile>> searchUsers(String query, {int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.userSearchEndpoint}/$query',
        queryParameters: {'limit': limit.toString()},
      );

      if (response is List) {
        return response
            .map((user) => UserProfile.fromJson(user as Map<String, dynamic>))
            .toList();
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List)
            .map((user) => UserProfile.fromJson(user as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('UserRepository: searchUsers error: $e');
    }
    return [];
  }

  /// Update user profile
  Future<UserProfile?> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
  }) async {
    try {
      final response = await _httpClient.patch(
        ApiConfig.userById(userId),
        body: {
          if (displayName != null) 'displayName': displayName,
          if (bio != null) 'bio': bio,
        },
      );

      if (response is Map<String, dynamic>) {
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('UserRepository: updateProfile error: $e');
      rethrow;
    }
    return null;
  }

  /// Update user avatar
  Future<UserProfile?> updateAvatar(String userId, String avatarUrl) async {
    try {
      final response = await _httpClient.patch(
        ApiConfig.userAvatar(userId),
        body: {'avatar': avatarUrl},
      );

      if (response is Map<String, dynamic>) {
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('UserRepository: updateAvatar error: $e');
      rethrow;
    }
    return null;
  }

  /// Get user statistics
  Future<UserStats?> getUserStats(String userId) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.userStats(userId),
      );

      if (response is Map<String, dynamic>) {
        return UserStats.fromJson(response);
      }
    } catch (e) {
      debugPrint('UserRepository: getUserStats error: $e');
    }
    return null;
  }
}

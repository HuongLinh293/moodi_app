import 'package:flutter/foundation.dart';
import '../core/http_client.dart';
import '../core/api_config.dart';
import 'user_repository.dart';

/// Represents a friend
class Friend {
  final String id;
  final String userId;
  final UserProfile friend;
  final String status;
  final DateTime createdAt;

  Friend({
    required this.id,
    required this.userId,
    required this.friend,
    required this.status,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      friend: UserProfile.fromJson(
        json['friend'] as Map<String, dynamic>? ?? {},
      ),
      status: json['status'] as String? ?? 'accepted',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

/// Represents a friend request
class FriendRequest {
  final String id;
  final String senderId;
  final UserProfile sender;
  final String recipientId;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.recipientId,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      sender: UserProfile.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      recipientId: json['recipientId'] as String? ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

/// Paginated friends response
class FriendsPage {
  final List<Friend> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  FriendsPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory FriendsPage.fromJson(Map<String, dynamic> json) {
    return FriendsPage(
      data: ((json['data'] as List?) ?? [])
          .map((f) => Friend.fromJson(f as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

/// Paginated friend requests response
class FriendRequestsPage {
  final List<FriendRequest> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  FriendRequestsPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory FriendRequestsPage.fromJson(Map<String, dynamic> json) {
    return FriendRequestsPage(
      data: ((json['data'] as List?) ?? [])
          .map((r) => FriendRequest.fromJson(r as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

class FriendRepository {
  final HttpClient _httpClient;

  FriendRepository({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Get friends list
  Future<FriendsPage?> getFriends({int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.friendsEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        return FriendsPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('FriendRepository: getFriends error: $e');
    }
    return null;
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String friendId) async {
    try {
      await _httpClient.post(
        ApiConfig.friendRequestsEndpoint,
        body: {'friendId': friendId},
      );
      return true;
    } catch (e) {
      debugPrint('FriendRepository: sendFriendRequest error: $e');
      rethrow;
    }
  }

  /// Get pending friend requests
  Future<FriendRequestsPage?> getFriendRequests(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.friendRequestsEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        return FriendRequestsPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('FriendRepository: getFriendRequests error: $e');
    }
    return null;
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      await _httpClient.post(
        ApiConfig.acceptFriendRequest(requestId),
        body: {},
      );
      return true;
    } catch (e) {
      debugPrint('FriendRepository: acceptFriendRequest error: $e');
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      await _httpClient.delete(
        ApiConfig.rejectFriendRequest(requestId),
      );
      return true;
    } catch (e) {
      debugPrint('FriendRepository: rejectFriendRequest error: $e');
      return false;
    }
  }

  /// Remove friend
  Future<bool> removeFriend(String friendId) async {
    try {
      await _httpClient.delete(
        ApiConfig.removeFriend(friendId),
      );
      return true;
    } catch (e) {
      debugPrint('FriendRepository: removeFriend error: $e');
      return false;
    }
  }

  /// Get friend suggestions
  Future<List<UserProfile>> getFriendSuggestions({int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.friendSuggestionsEndpoint,
        queryParameters: {'limit': limit.toString()},
      );

      if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List)
            .map((user) => UserProfile.fromJson(user as Map<String, dynamic>))
            .toList();
      } else if (response is List) {
        return response
            .map((user) => UserProfile.fromJson(user as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('FriendRepository: getFriendSuggestions error: $e');
    }
    return [];
  }
}

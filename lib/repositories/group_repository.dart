import 'package:flutter/foundation.dart';
import '../core/http_client.dart';
import '../core/api_config.dart';
import 'user_repository.dart';

/// Represents a group member
class GroupMember {
  final String id;
  final String userId;
  final UserProfile user;
  final String role; // admin, moderator, member
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.userId,
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      user: UserProfile.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(
        json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

/// Represents a group
class Group {
  final String id;
  final String name;
  final String? description;
  final String? image;
  final UserProfile? createdBy;
  final int memberCount;
  final bool isMember;
  final DateTime createdAt;
  final DateTime updatedAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.createdBy,
    required this.memberCount,
    required this.isMember,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      image: json['image'] as String?,
      createdBy: json['createdBy'] != null
          ? UserProfile.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      memberCount: json['memberCount'] as int? ?? 0,
      isMember: json['isMember'] as bool? ?? false,
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
      'name': name,
      'description': description,
      'image': image,
      'memberCount': memberCount,
      'isMember': isMember,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Paginated groups response
class GroupsPage {
  final List<Group> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  GroupsPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory GroupsPage.fromJson(Map<String, dynamic> json) {
    return GroupsPage(
      data: ((json['data'] as List?) ?? [])
          .map((g) => Group.fromJson(g as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

/// Paginated members response
class MembersPage {
  final List<GroupMember> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  MembersPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory MembersPage.fromJson(Map<String, dynamic> json) {
    return MembersPage(
      data: ((json['data'] as List?) ?? [])
          .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

class GroupRepository {
  final HttpClient _httpClient;

  GroupRepository({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Get user's groups
  Future<GroupsPage?> getGroups({int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.groupsEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        return GroupsPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('GroupRepository: getGroups error: $e');
    }
    return null;
  }

  /// Create a new group
  Future<Group?> createGroup({
    required String name,
    String? description,
    String? image,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.groupsEndpoint,
        body: {
          'name': name,
          if (description != null) 'description': description,
          if (image != null) 'image': image,
        },
      );

      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          return Group.fromJson(response['data'] as Map<String, dynamic>);
        }
        return Group.fromJson(response);
      }
    } catch (e) {
      debugPrint('GroupRepository: createGroup error: $e');
      rethrow;
    }
    return null;
  }

  /// Get group details
  Future<Group?> getGroupById(String groupId) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.groupById(groupId),
      );

      if (response is Map<String, dynamic>) {
        return Group.fromJson(response);
      }
    } catch (e) {
      debugPrint('GroupRepository: getGroupById error: $e');
    }
    return null;
  }

  /// Update group info
  Future<Group?> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? image,
  }) async {
    try {
      final response = await _httpClient.patch(
        ApiConfig.groupById(groupId),
        body: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (image != null) 'image': image,
        },
      );

      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          return Group.fromJson(response['data'] as Map<String, dynamic>);
        }
        return Group.fromJson(response);
      }
    } catch (e) {
      debugPrint('GroupRepository: updateGroup error: $e');
      rethrow;
    }
    return null;
  }

  /// Delete group
  Future<bool> deleteGroup(String groupId) async {
    try {
      await _httpClient.delete(
        ApiConfig.groupById(groupId),
      );
      return true;
    } catch (e) {
      debugPrint('GroupRepository: deleteGroup error: $e');
      return false;
    }
  }

  /// Get group members
  Future<MembersPage?> getGroupMembers(String groupId,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.groupMembers(groupId),
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        return MembersPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('GroupRepository: getGroupMembers error: $e');
    }
    return null;
  }

  /// Add member to group
  Future<bool> addMember(String groupId, String userId) async {
    try {
      await _httpClient.post(
        ApiConfig.addGroupMember(groupId),
        body: {'userId': userId},
      );
      return true;
    } catch (e) {
      debugPrint('GroupRepository: addMember error: $e');
      return false;
    }
  }

  /// Remove member from group
  Future<bool> removeMember(String groupId, String userId) async {
    try {
      await _httpClient.delete(
        ApiConfig.removeGroupMember(groupId, userId),
      );
      return true;
    } catch (e) {
      debugPrint('GroupRepository: removeMember error: $e');
      return false;
    }
  }

  /// Leave group
  Future<bool> leaveGroup(String groupId) async {
    try {
      await _httpClient.post(
        ApiConfig.leaveGroup(groupId),
        body: {},
      );
      return true;
    } catch (e) {
      debugPrint('GroupRepository: leaveGroup error: $e');
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import '../core/http_client.dart';
import '../core/api_config.dart';
import 'user_repository.dart';

/// Represents a chat message
class Message {
  final String id;
  final String conversationId;
  final UserProfile sender;
  final String content;
  final List<String>? imageUrls;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    this.imageUrls,
    required this.isEdited,
    this.editedAt,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      sender: UserProfile.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      content: json['content'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List?)?.cast<String>(),
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender.toJson(),
      'content': content,
      'imageUrls': imageUrls,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Represents a conversation
class Conversation {
  final String id;
  final String type; // direct, group
  final String? name;
  final List<UserProfile> participants;
  final Message? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime joinedAt;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    required this.participants,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    required this.joinedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'direct',
      name: json['name'] as String?,
      participants: ((json['participants'] as List?) ?? [])
          .map((p) => UserProfile.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      joinedAt: DateTime.parse(
        json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

/// Paginated messages response
class MessagesPage {
  final List<Message> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  MessagesPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory MessagesPage.fromJson(Map<String, dynamic> json) {
    return MessagesPage(
      data: ((json['data'] as List?) ?? [])
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 20,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

/// Paginated conversations response
class ConversationsPage {
  final List<Conversation> data;
  final int page;
  final int limit;
  final int total;
  final int pages;

  ConversationsPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory ConversationsPage.fromJson(Map<String, dynamic> json) {
    return ConversationsPage(
      data: ((json['data'] as List?) ?? [])
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
          .toList(),
      page: json['pagination']?['page'] as int? ?? 1,
      limit: json['pagination']?['limit'] as int? ?? 10,
      total: json['pagination']?['total'] as int? ?? 0,
      pages: json['pagination']?['pages'] as int? ?? 1,
    );
  }
}

class ChatRepository {
  final HttpClient _httpClient;

  ChatRepository({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Get conversations for current user
  Future<ConversationsPage?> getConversations(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.conversationsEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        return ConversationsPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('ChatRepository: getConversations error: $e');
    }
    return null;
  }

  /// Create a new conversation
  Future<Conversation?> createConversation({
    required String type, // direct, group
    String? name,
    required List<String> participantIds,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.conversationsEndpoint,
        body: {
          'type': type,
          if (name != null) 'name': name,
          'participantIds': participantIds,
        },
      );

      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          return Conversation.fromJson(
              response['data'] as Map<String, dynamic>);
        }
        return Conversation.fromJson(response);
      }
    } catch (e) {
      debugPrint('ChatRepository: createConversation error: $e');
      rethrow;
    }
    return null;
  }

  /// Get conversation details
  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.conversationById(conversationId),
      );

      if (response is Map<String, dynamic>) {
        return Conversation.fromJson(response);
      }
    } catch (e) {
      debugPrint('ChatRepository: getConversationById error: $e');
    }
    return null;
  }

  /// Delete/leave conversation
  Future<bool> deleteConversation(String conversationId) async {
    try {
      await _httpClient.delete(
        ApiConfig.conversationById(conversationId),
      );
      return true;
    } catch (e) {
      debugPrint('ChatRepository: deleteConversation error: $e');
      return false;
    }
  }

  /// Get messages in conversation
  Future<MessagesPage?> getMessages(String conversationId,
      {int page = 1, int limit = 20}) async {
    try {
      final response = await _httpClient.get(
        ApiConfig.conversationMessages(conversationId),
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        return MessagesPage.fromJson(response);
      }
    } catch (e) {
      debugPrint('ChatRepository: getMessages error: $e');
    }
    return null;
  }

  /// Send message via REST API
  Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    List<String>? imageUrls,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.sendMessage(conversationId),
        body: {
          'content': content,
          if (imageUrls != null) 'imageUrls': imageUrls,
        },
      );

      if (response is Map<String, dynamic>) {
        if (response['data'] is Map<String, dynamic>) {
          return Message.fromJson(response['data'] as Map<String, dynamic>);
        }
        return Message.fromJson(response);
      }
    } catch (e) {
      debugPrint('ChatRepository: sendMessage error: $e');
      rethrow;
    }
    return null;
  }

  /// WebSocket URL for real-time connection
  String get webSocketUrl {
    final baseUrl = ApiConfig.baseUrl.replaceFirst('http://', 'ws://');
    return baseUrl.replaceFirst('https://', 'wss://');
  }
}

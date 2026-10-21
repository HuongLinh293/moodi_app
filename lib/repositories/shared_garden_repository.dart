import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/api_config.dart';
import '../models/shared_garden.dart';

class SharedGardenRepository {
  final HttpClient _httpClient;
  String? _currentUserId;

  SharedGardenRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Set the current user ID for API calls
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Get current user ID
  String get _uid {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      throw StateError('Hãy đăng nhập để sử dụng vườn chung.');
    }
    return _currentUserId!;
  }

  /// Create a new shared garden
  Future<SharedGarden> createGarden({
    required String userId,
    required String userName,
    String? gardenName,
  }) async {
    if (_uid != userId) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }

    try {
      final response = await _httpClient.post(
        '${ApiConfig.sharedGardenEndpoint}/create',
        body: {
          'userId': userId,
          'userName': userName,
          'gardenName': gardenName ?? 'Vườn sẻ chia',
        },
      );

      if (response is Map<String, dynamic>) {
        return SharedGarden.fromFirestore(
          response,
          response['id'] as String? ?? '',
        );
      }

      throw StateError('Invalid response from server');
    } catch (e) {
      debugPrint('SharedGardenRepository: Error creating garden: $e');
      rethrow;
    }
  }

  /// Join a shared garden using an invite code
  Future<SharedGarden?> joinGardenByCode({
    required String code,
    required String userId,
    required String userName,
  }) async {
    if (_uid != userId) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }

    try {
      final cleanCode = code.trim().toUpperCase();

      if (!RegExp(r'^MD-[A-F0-9]{32}$').hasMatch(cleanCode)) {
        throw StateError(
          'Mã mời đã cũ hoặc không hợp lệ. Hãy nhờ bạn gửi mã mới.',
        );
      }

      final response = await _httpClient.post(
        '${ApiConfig.sharedGardenEndpoint}/join',
        body: {'code': cleanCode, 'userId': userId, 'userName': userName},
      );

      if (response is Map<String, dynamic>) {
        return SharedGarden.fromFirestore(
          response,
          response['id'] as String? ?? '',
        );
      }

      return null;
    } catch (e) {
      debugPrint('SharedGardenRepository: Error joining garden: $e');
      rethrow;
    }
  }

  /// Watch user's shared garden (polling)
  Stream<SharedGarden?> watchUserGarden(String userId) {
    const pollInterval = Duration(seconds: 5);

    return Stream.periodic(pollInterval, (_) async {
      try {
        final response = await _httpClient.get(
          '${ApiConfig.sharedGardenEndpoint}/user-garden',
          queryParameters: {'userId': userId},
        );

        if (response is Map<String, dynamic> && response['id'] != null) {
          return SharedGarden.fromFirestore(response, response['id'] as String);
        }
        return null;
      } catch (e) {
        debugPrint('SharedGardenRepository: Error watching user garden: $e');
        rethrow;
      }
    }).asyncExpand((future) => future.asStream());
  }

  /// Watch specific shared garden
  Stream<SharedGarden?> watchGarden(String gardenId) {
    const pollInterval = Duration(seconds: 5);

    return Stream.periodic(pollInterval, (_) async {
      try {
        final response = await _httpClient.get(
          '${ApiConfig.sharedGardenEndpoint}/$gardenId',
        );

        if (response is Map<String, dynamic>) {
          return SharedGarden.fromFirestore(response, gardenId);
        }
        return null;
      } catch (e) {
        debugPrint('SharedGardenRepository: Error watching garden: $e');
        rethrow;
      }
    }).asyncExpand((future) => future.asStream());
  }

  /// Watch moments in a shared garden (polling)
  Stream<List<SharedMoment>> watchMoments(String gardenId) {
    const pollInterval = Duration(seconds: 5);

    return Stream.periodic(pollInterval, (_) async {
      try {
        final response = await _httpClient.get(
          '${ApiConfig.sharedGardenEndpoint}/$gardenId/moments',
        );

        if (response is List) {
          return response
              .whereType<Map<String, dynamic>>()
              .map(
                (data) => SharedMoment.fromFirestore(
                  data,
                  data['id'] as String? ?? '',
                ),
              )
              .toList();
        } else if (response is Map<String, dynamic>) {
          final data = response['moments'] ?? response['data'] ?? [];
          if (data is List) {
            return data
                .whereType<Map<String, dynamic>>()
                .map(
                  (moment) => SharedMoment.fromFirestore(
                    moment,
                    moment['id'] as String? ?? '',
                  ),
                )
                .toList();
          }
        }
        return <SharedMoment>[];
      } catch (e) {
        debugPrint('SharedGardenRepository: Error watching moments: $e');
        rethrow;
      }
    }).asyncExpand((future) => future.asStream());
  }

  /// Plant a journal entry in the shared garden
  Future<SharedMoment> plantEntry(
    String gardenId,
    String entryId, {
    bool includeCaption = false,
  }) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/plant',
        body: {'entryId': entryId, 'includeCaption': includeCaption},
      );

      if (response is Map<String, dynamic>) {
        return SharedMoment.fromFirestore(
          response,
          response['id'] as String? ?? '',
        );
      }

      throw StateError('Invalid response from server');
    } catch (e) {
      debugPrint('SharedGardenRepository: Error planting entry: $e');
      rethrow;
    }
  }

  /// Remove a moment from the shared garden
  Future<void> removeMoment(String gardenId, String momentId) async {
    try {
      await _httpClient.delete(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/moments/$momentId',
      );
    } catch (e) {
      debugPrint('SharedGardenRepository: Error removing moment: $e');
      rethrow;
    }
  }

  /// Remove all moments from current user in a garden
  Future<void> removeMyMoments(String gardenId) async {
    try {
      await _httpClient.delete(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/my-moments',
      );
    } catch (e) {
      debugPrint('SharedGardenRepository: Error removing my moments: $e');
      rethrow;
    }
  }

  /// Leave a shared garden
  Future<void> leaveGarden(String gardenId) async {
    try {
      await _httpClient.post(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/leave',
        body: {},
      );
    } catch (e) {
      debugPrint('SharedGardenRepository: Error leaving garden: $e');
      rethrow;
    }
  }

  /// Refresh the invite code for a garden
  Future<String> refreshInvite(String gardenId) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/refresh-invite',
        body: {},
      );

      if (response is Map<String, dynamic>) {
        return response['code'] as String? ?? '';
      }

      throw StateError('Failed to refresh invite code');
    } catch (e) {
      debugPrint('SharedGardenRepository: Error refreshing invite: $e');
      rethrow;
    }
  }

  /// Interact with a moment (water or sun)
  Future<SharedMoment> interactMoment({
    required String gardenId,
    required String momentId,
    required bool isWater,
    required String interactorName,
  }) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/moments/$momentId/interact',
        body: {'isWater': isWater, 'interactorName': interactorName},
      );

      if (response is Map<String, dynamic>) {
        return SharedMoment.fromFirestore(response, momentId);
      }

      throw StateError('Invalid response from server');
    } catch (e) {
      debugPrint('SharedGardenRepository: Error interacting with moment: $e');
      rethrow;
    }
  }

  /// Get a shared garden by ID
  Future<SharedGarden?> getGarden(String gardenId) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId',
      );

      if (response is Map<String, dynamic>) {
        return SharedGarden.fromFirestore(response, gardenId);
      }

      return null;
    } catch (e) {
      debugPrint('SharedGardenRepository: Error getting garden: $e');
      rethrow;
    }
  }

  /// Get user's current garden
  Future<SharedGarden?> getUserGarden(String userId) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.sharedGardenEndpoint}/user-garden',
        queryParameters: {'userId': userId},
      );

      if (response is Map<String, dynamic> && response['id'] != null) {
        return SharedGarden.fromFirestore(response, response['id'] as String);
      }

      return null;
    } catch (e) {
      debugPrint('SharedGardenRepository: Error getting user garden: $e');
      rethrow;
    }
  }

  /// Get moments in a garden
  Future<List<SharedMoment>> getMoments(String gardenId) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.sharedGardenEndpoint}/$gardenId/moments',
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map(
              (data) =>
                  SharedMoment.fromFirestore(data, data['id'] as String? ?? ''),
            )
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['moments'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(
                (moment) => SharedMoment.fromFirestore(
                  moment,
                  moment['id'] as String? ?? '',
                ),
              )
              .toList();
        }
      }
      return <SharedMoment>[];
    } catch (e) {
      debugPrint('SharedGardenRepository: Error getting moments: $e');
      rethrow;
    }
  }

  void dispose() {
    // Clean up resources if needed
  }
}

import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/api_config.dart';
import '../models/garden_moment.dart';

class GardenRepository {
  final HttpClient _httpClient;

  GardenRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Save or update a garden moment
  Future<void> saveMoment(GardenMoment moment, {String? userId}) async {
    if (userId == null || userId.isEmpty) {
      throw StateError('Hãy đăng nhập trước khi lưu.');
    }
    try {
      final body = {
        'id': moment.id,
        'entryId': moment.entryId,
        'monthKey': moment.monthKey,
        'bedIndex': moment.bedIndex,
        'slotIndex': moment.slotIndex,
        'plantedAt': moment.plantedAt.toUtc().toIso8601String(),
        'appearanceVariant': moment.appearanceVariant,
      };

      body['userId'] = userId;

      final endpoint = moment.id.isEmpty
          ? ApiConfig.momentsEndpoint
          : '${ApiConfig.momentsEndpoint}/${moment.id}';

      if (moment.id.isEmpty) {
        await _httpClient.post(ApiConfig.momentsEndpoint, body: body);
      } else {
        await _httpClient.put(endpoint, body: body);
      }
    } catch (e) {
      debugPrint('GardenRepository: Error saving moment $e');
      rethrow;
    }
  }

  /// Delete a garden moment
  Future<void> deleteMoment(String momentId, {required String userId}) async {
    try {
      await _httpClient.delete('${ApiConfig.momentsEndpoint}/$momentId');
    } catch (e) {
      debugPrint('GardenRepository: Error deleting moment $e');
      rethrow;
    }
  }

  /// Delete all garden moments for a user
  Future<void> deleteAllMoments({required String userId}) async {
    try {
      await _httpClient.delete(
        ApiConfig.momentsEndpoint,
        headers: {'X-Delete-All': 'true'},
      );
    } catch (e) {
      debugPrint('GardenRepository: Error deleting all moments $e');
      rethrow;
    }
  }

  /// Fetch all garden moments
  Future<List<GardenMoment>> fetchMoments({String? userId}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) {
        queryParams['userId'] = userId;
      }

      final response = await _httpClient.get(
        ApiConfig.momentsEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => GardenMoment.fromJson(data))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['moments'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((moment) => GardenMoment.fromJson(moment))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('GardenRepository: Error fetching moments $e');
      rethrow;
    }
  }

  /// Watch garden moments (simulated polling for REST API)
  /// Note: REST APIs don't support real-time streaming like Firestore.
  /// This implementation returns a stream using periodic polling.
  Stream<List<GardenMoment>> watchMoments({String? userId}) {
    const pollInterval = Duration(seconds: 5);

    return Stream.periodic(pollInterval, (_) async {
      try {
        return await fetchMoments(userId: userId);
      } catch (e) {
        debugPrint('GardenRepository: Error watching moments: $e');
        rethrow;
      }
    }).asyncExpand((future) => future.asStream());
  }

  /// Fetch a single moment by ID
  Future<GardenMoment?> fetchMoment(String momentId) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.momentsEndpoint}/$momentId',
      );

      if (response is Map<String, dynamic>) {
        return GardenMoment.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('GardenRepository: Error fetching moment: $e');
      rethrow;
    }
  }

  /// Fetch moments for a specific month
  Future<List<GardenMoment>> fetchMomentsForMonth(
    int year,
    int month, {
    String? userId,
  }) async {
    try {
      final monthKey = '${year.toString()}-${month.toString().padLeft(2, '0')}';
      final queryParams = <String, String>{'monthKey': monthKey};

      if (userId != null) {
        queryParams['userId'] = userId;
      }

      final response = await _httpClient.get(
        '${ApiConfig.momentsEndpoint}/month/$monthKey',
        queryParameters: queryParams,
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => GardenMoment.fromJson(data))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['moments'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((moment) => GardenMoment.fromJson(moment))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('GardenRepository: Error fetching moments for month: $e');
      rethrow;
    }
  }

  /// Fetch moments for a specific bed
  Future<List<GardenMoment>> fetchMomentsForBed(
    int bedIndex, {
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{'bedIndex': bedIndex.toString()};

      if (userId != null) {
        queryParams['userId'] = userId;
      }

      final response = await _httpClient.get(
        '${ApiConfig.momentsEndpoint}/bed/$bedIndex',
        queryParameters: queryParams,
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => GardenMoment.fromJson(data))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['moments'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((moment) => GardenMoment.fromJson(moment))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('GardenRepository: Error fetching moments for bed: $e');
      rethrow;
    }
  }

  /// Get moments grouped by bed
  Future<Map<int, List<GardenMoment>>> fetchMomentsGroupedByBed({
    String? userId,
  }) async {
    try {
      final moments = await fetchMoments(userId: userId);
      final grouped = <int, List<GardenMoment>>{};

      for (final moment in moments) {
        if (!grouped.containsKey(moment.bedIndex)) {
          grouped[moment.bedIndex] = [];
        }
        grouped[moment.bedIndex]!.add(moment);
      }

      return grouped;
    } catch (e) {
      debugPrint('GardenRepository: Error grouping moments by bed: $e');
      return {};
    }
  }
}

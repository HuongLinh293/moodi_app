import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/api_config.dart';
import '../models/journal_entry.dart';

class JournalRepository {
  final HttpClient _httpClient;

  JournalRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Save or update a journal entry
  Future<void> saveEntry(JournalEntry entry, {String? userId}) async {
    if (userId == null || userId.isEmpty) {
      throw StateError('Hãy đăng nhập trước khi lưu.');
    }
    try {
      final body = {
        'id': entry.id,
        'timestamp': entry.timestamp.toUtc().toIso8601String(),
        'emotionKey': entry.emotionKey,
        'intensity': entry.intensity,
        'trigger': entry.trigger,
        'situation': entry.situation,
        'thought': entry.thought,
        'response': entry.response,
        'exerciseId': entry.exerciseId,
        'exerciseDone': entry.exerciseDone,
        'afterIntensity': entry.afterIntensity,
        'afterEmotionKey': entry.afterEmotionKey,
        'usefulnessRating': entry.usefulnessRating,
        'easeRating': entry.easeRating,
        'repeatPreference': entry.repeatPreference,
      };

      body['userId'] = userId;

      final endpoint = entry.id.isEmpty
          ? ApiConfig.entriesEndpoint
          : '${ApiConfig.entriesEndpoint}/${entry.id}';

      if (entry.id.isEmpty) {
        await _httpClient.post(ApiConfig.entriesEndpoint, body: body);
      } else {
        await _httpClient.put(endpoint, body: body);
      }
    } catch (e) {
      debugPrint('JournalRepository: Error saving entry $e');
      rethrow;
    }
  }

  /// Fetch all journal entries for a user
  Future<List<JournalEntry>> fetchEntries({String? userId}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) {
        queryParams['userId'] = userId;
      }

      final response = await _httpClient.get(
        ApiConfig.entriesEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => JournalEntry.fromJson(data))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['entries'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((entry) => JournalEntry.fromJson(entry))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('JournalRepository: Error fetching entries $e');
      rethrow;
    }
  }

  /// Delete a journal entry
  Future<void> deleteEntry(String entryId, {String? userId}) async {
    try {
      // Delete the entry
      await _httpClient.delete('${ApiConfig.entriesEndpoint}/$entryId');

      // Also delete associated garden moment if it exists
      try {
        await _httpClient.delete(
          '${ApiConfig.momentsEndpoint}/garden-$entryId',
        );
      } catch (e) {
        // Ignore error if garden moment doesn't exist
        debugPrint(
          'JournalRepository: No associated garden moment to delete: $e',
        );
      }
    } catch (e) {
      debugPrint('JournalRepository: Error deleting entry $e');
      rethrow;
    }
  }

  /// Delete all entries for a user
  Future<void> deleteAllEntries({required String userId}) async {
    try {
      await _httpClient.delete(
        ApiConfig.entriesEndpoint,
        headers: {'X-Delete-All': 'true'},
      );
    } catch (e) {
      debugPrint('JournalRepository: Error deleting all entries $e');
      rethrow;
    }
  }

  /// Watch journal entries (simulated polling for REST API)
  /// Note: REST APIs don't support real-time streaming like Firestore.
  /// This implementation returns a stream using periodic polling.
  Stream<List<JournalEntry>> watchEntries({String? userId}) {
    const pollInterval = Duration(seconds: 5);

    return Stream.periodic(pollInterval, (_) async {
      try {
        return await fetchEntries(userId: userId);
      } catch (e) {
        debugPrint('JournalRepository: Error watching entries: $e');
        rethrow;
      }
    }).asyncExpand((future) => future.asStream());
  }

  /// Fetch a single entry by ID
  Future<JournalEntry?> fetchEntry(String entryId) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.entriesEndpoint}/$entryId',
      );

      if (response is Map<String, dynamic>) {
        return JournalEntry.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('JournalRepository: Error fetching entry: $e');
      rethrow;
    }
  }

  /// Search entries by emotion key
  Future<List<JournalEntry>> searchByEmotion(
    String emotionKey, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{'emotionKey': emotionKey};

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final response = await _httpClient.get(
        '${ApiConfig.entriesEndpoint}/search',
        queryParameters: queryParams,
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => JournalEntry.fromJson(data))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['entries'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((entry) => JournalEntry.fromJson(entry))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('JournalRepository: Error searching entries: $e');
      rethrow;
    }
  }

  /// Get entries for a specific date
  Future<List<JournalEntry>> fetchEntriesForDate(DateTime date) async {
    try {
      final response = await _httpClient.get(
        '${ApiConfig.entriesEndpoint}/date/${date.toIso8601String().split('T')[0]}',
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => JournalEntry.fromJson(data))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('JournalRepository: Error fetching entries for date: $e');
      rethrow;
    }
  }
}

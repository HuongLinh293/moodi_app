import 'package:flutter/foundation.dart';
import '../core/http_client.dart';
import '../core/api_config.dart';
import '../models/ai_reflection.dart';

class ReflectionRepository {
  final HttpClient _httpClient;

  ReflectionRepository({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Generate AI reflection based on emotion and context
  Future<AIReflection> generateReflection({
    required String emotionKey,
    required int intensity,
    String? situation,
    String? thought,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.generateReflectionEndpoint,
        body: {
          'emotionKey': emotionKey,
          'intensity': intensity,
          'situation': situation ?? '',
          'thought': thought ?? '',
        },
      );

      if (response is Map<String, dynamic>) {
        final reflection = AIReflection.fromJson(response);
        debugPrint(
            'ReflectionRepository: Successfully generated reflection from API');
        return reflection;
      }
    } catch (e) {
      debugPrint(
          'ReflectionRepository: API call failed ($e), falling back to local model');
    }

    // Fallback to local CBT reflection model if API fails
    return AIReflection.forEmotion(
      emotionKey: emotionKey,
      intensity: intensity,
      situation: situation,
      thought: thought,
    );
  }

  /// Get reflection history for a user
  Future<List<AIReflection>> getReflectionHistory({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (userId != null) {
        queryParams['userId'] = userId;
      }

      final response = await _httpClient.get(
        '${ApiConfig.reflectionEndpoint}/history',
        queryParameters: queryParams,
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((data) => AIReflection.fromJson(data))
            .toList();
      } else if (response is Map<String, dynamic>) {
        final data = response['reflections'] ?? response['data'] ?? [];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((reflection) => AIReflection.fromJson(reflection))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('ReflectionRepository: Error fetching reflection history: $e');
      return [];
    }
  }

  /// Save user feedback on a reflection
  Future<void> saveReflectionFeedback({
    required String reflectionId,
    required String feedback,
    required bool helpful,
  }) async {
    try {
      await _httpClient.post(
        '${ApiConfig.reflectionEndpoint}/$reflectionId/feedback',
        body: {
          'feedback': feedback,
          'helpful': helpful,
        },
      );

      debugPrint('ReflectionRepository: Feedback saved successfully');
    } catch (e) {
      debugPrint('ReflectionRepository: Error saving feedback: $e');
      rethrow;
    }
  }

  /// Get recommended exercise for current emotion
  Future<Map<String, dynamic>> getRecommendedExercise({
    required String emotionKey,
    required int intensity,
  }) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.reflectionEndpoint}/exercise',
        body: {
          'emotionKey': emotionKey,
          'intensity': intensity,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      debugPrint('ReflectionRepository: Error getting exercise: $e');
      return {};
    }
  }

  /// Check safety flag for given text
  Future<bool> checkSafetyFlag({
    required String situation,
    required String thought,
  }) async {
    try {
      final response = await _httpClient.post(
        '${ApiConfig.reflectionEndpoint}/safety-check',
        body: {
          'situation': situation,
          'thought': thought,
        },
      );

      if (response is Map<String, dynamic>) {
        return response['isSafe'] as bool? ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('ReflectionRepository: Error checking safety: $e');
      // Default to safe if API check fails
      return true;
    }
  }

  /// Get AI insights based on user data
  Future<Map<String, dynamic>> getAIInsights({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (userId != null) {
        queryParams['userId'] = userId;
      }

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final response = await _httpClient.get(
        '${ApiConfig.reflectionEndpoint}/insights',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      debugPrint('ReflectionRepository: Error getting insights: $e');
      return {};
    }
  }
}

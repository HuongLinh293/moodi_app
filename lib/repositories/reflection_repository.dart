import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/ai_reflection.dart';

class ReflectionRepository {
  final FirebaseFunctions? functions;

  ReflectionRepository({this.functions});

  FirebaseFunctions get _instance =>
      functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<AIReflection> generateReflection({
    required String emotionKey,
    required int intensity,
    String? situation,
    String? thought,
  }) async {
    try {
      final callable = _instance.httpsCallable('generateReflection');
      final response = await callable.call<dynamic>({
        'emotionKey': emotionKey,
        'intensity': intensity,
        'situation': situation ?? '',
        'thought': thought ?? '',
      });

      if (response.data != null && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return AIReflection.fromJson(data);
      }
    } catch (e) {
      debugPrint(
          'ReflectionRepository: Cloud Function failed ($e), falling back to local model');
    }

    // Always fallback to reliable local CBT reflection model
    return AIReflection.forEmotion(
      emotionKey: emotionKey,
      intensity: intensity,
      situation: situation,
      thought: thought,
    );
  }
}

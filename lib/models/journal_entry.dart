class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String emotionKey;
  final int intensity;
  final String trigger;
  final String situation;
  final String thought;
  final String response;
  final String? exerciseId;
  final bool exerciseDone;
  final int? afterIntensity;
  final String? afterEmotionKey;
  final int? usefulnessRating;
  final int? easeRating;
  final String? repeatPreference;

  const JournalEntry({
    required this.id,
    required this.timestamp,
    required this.emotionKey,
    required this.intensity,
    this.trigger = 'other',
    this.situation = '',
    this.thought = '',
    this.response = '',
    this.exerciseId,
    this.exerciseDone = false,
    this.afterIntensity,
    this.afterEmotionKey,
    this.usefulnessRating,
    this.easeRating,
    this.repeatPreference,
  });

  JournalEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? emotionKey,
    int? intensity,
    String? trigger,
    String? situation,
    String? thought,
    String? response,
    String? exerciseId,
    bool? exerciseDone,
    int? afterIntensity,
    String? afterEmotionKey,
    int? usefulnessRating,
    int? easeRating,
    String? repeatPreference,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      emotionKey: emotionKey ?? this.emotionKey,
      intensity: intensity ?? this.intensity,
      trigger: trigger ?? this.trigger,
      situation: situation ?? this.situation,
      thought: thought ?? this.thought,
      response: response ?? this.response,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseDone: exerciseDone ?? this.exerciseDone,
      afterIntensity: afterIntensity ?? this.afterIntensity,
      afterEmotionKey: afterEmotionKey ?? this.afterEmotionKey,
      usefulnessRating: usefulnessRating ?? this.usefulnessRating,
      easeRating: easeRating ?? this.easeRating,
      repeatPreference: repeatPreference ?? this.repeatPreference,
    );
  }

  Map<String, dynamic> toFirestore({String? userId}) {
    final map = <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'emotionKey': emotionKey,
      'intensity': intensity,
      'trigger': trigger,
      'situation': situation,
      'thought': thought,
      'response': response,
      'exerciseId': exerciseId,
      'exerciseDone': exerciseDone,
      'afterIntensity': afterIntensity,
      'afterEmotionKey': afterEmotionKey,
      'usefulnessRating': usefulnessRating,
      'easeRating': easeRating,
      'repeatPreference': repeatPreference,
    };
    if (userId != null) {
      map['userId'] = userId;
    }
    return map;
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory JournalEntry.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseTime(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      try {
        // Handle cloud_firestore Timestamp without hard dependency
        final dynamic d = raw;
        if (d.toDate != null) return d.toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    return JournalEntry(
      id: id,
      timestamp: parseTime(data['timestamp']),
      emotionKey: data['emotionKey'] as String? ?? 'calm',
      intensity: (data['intensity'] as num?)?.toInt() ?? 3,
      trigger: data['trigger'] as String? ?? 'other',
      situation: data['situation'] as String? ?? '',
      thought: data['thought'] as String? ?? '',
      response: data['response'] as String? ?? '',
      exerciseId: data['exerciseId'] as String?,
      exerciseDone: data['exerciseDone'] as bool? ?? false,
      afterIntensity: (data['afterIntensity'] as num?)?.toInt(),
      afterEmotionKey: data['afterEmotionKey'] as String?,
      usefulnessRating: (data['usefulnessRating'] as num?)?.toInt(),
      easeRating: (data['easeRating'] as num?)?.toInt(),
      repeatPreference: data['repeatPreference'] as String?,
    );
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json, [String? id]) {
    return JournalEntry.fromFirestore(json, id ?? json['id'] as String? ?? '');
  }
}


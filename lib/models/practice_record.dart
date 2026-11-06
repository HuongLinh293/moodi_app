class PracticeRecord {
  const PracticeRecord({
    required this.id,
    required this.exerciseId,
    required this.timestamp,
    this.sourceEntryId,
    this.note = '',
    this.beforeEmotionKey,
    this.beforeIntensity,
    this.afterEmotionKey,
    this.afterIntensity,
    this.usefulnessRating,
    this.easeRating,
    this.repeatPreference,
  });
  final String id, exerciseId, note;
  final DateTime timestamp;
  final String? sourceEntryId,
      beforeEmotionKey,
      afterEmotionKey,
      repeatPreference;
  final int? beforeIntensity, afterIntensity, usefulnessRating, easeRating;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'sourceEntryId': sourceEntryId,
    'note': note,
    'beforeEmotionKey': beforeEmotionKey,
    'beforeIntensity': beforeIntensity,
    'afterEmotionKey': afterEmotionKey,
    'afterIntensity': afterIntensity,
    'usefulnessRating': usefulnessRating,
    'easeRating': easeRating,
    'repeatPreference': repeatPreference,
  };
  factory PracticeRecord.fromJson(Map<String, dynamic> json) => PracticeRecord(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    sourceEntryId: json['sourceEntryId'] as String?,
    note: json['note'] as String? ?? '',
    beforeEmotionKey: json['beforeEmotionKey'] as String?,
    beforeIntensity: json['beforeIntensity'] as int?,
    afterEmotionKey: json['afterEmotionKey'] as String?,
    afterIntensity: json['afterIntensity'] as int?,
    usefulnessRating: json['usefulnessRating'] as int?,
    easeRating: json['easeRating'] as int?,
    repeatPreference: json['repeatPreference'] as String?,
  );
}

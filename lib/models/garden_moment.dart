import 'journal_entry.dart';

class GardenMoment {
  final String id;
  final String entryId;
  final String monthKey;
  final int bedIndex;
  final int slotIndex;
  final DateTime plantedAt;
  final int appearanceVariant;

  const GardenMoment({
    required this.id,
    required this.entryId,
    required this.monthKey,
    required this.bedIndex,
    required this.slotIndex,
    required this.plantedAt,
    this.appearanceVariant = 0,
  });

  static String monthKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static String captionFor(JournalEntry entry) {
    if (entry.situation.trim().isNotEmpty) return entry.situation.trim();
    if (entry.thought.trim().isNotEmpty) return entry.thought.trim();
    return '';
  }

  Map<String, dynamic> toFirestore({String? userId}) {
    final map = <String, dynamic>{
      'entryId': entryId,
      'monthKey': monthKey,
      'bedIndex': bedIndex,
      'slotIndex': slotIndex,
      'plantedAt': plantedAt.toIso8601String(),
      'appearanceVariant': appearanceVariant,
    };
    if (userId != null) {
      map['userId'] = userId;
    }
    return map;
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory GardenMoment.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseTime(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      try {
        final dynamic d = raw;
        if (d.toDate != null) return d.toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    return GardenMoment(
      id: id,
      entryId: data['entryId'] as String? ?? '',
      monthKey: data['monthKey'] as String? ?? '',
      bedIndex: (data['bedIndex'] as num?)?.toInt() ?? 0,
      slotIndex: (data['slotIndex'] as num?)?.toInt() ?? 0,
      plantedAt: parseTime(data['plantedAt']),
      appearanceVariant: (data['appearanceVariant'] as num?)?.toInt() ?? 0,
    );
  }

  factory GardenMoment.fromJson(Map<String, dynamic> json, [String? id]) {
    return GardenMoment.fromFirestore(json, id ?? json['id'] as String? ?? '');
  }
}

class GardenBedGroup {
  final int bedIndex;
  final List<GardenMoment> moments;

  const GardenBedGroup({required this.bedIndex, required this.moments});
}

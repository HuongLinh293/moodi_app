class SharedGarden {
  final String id;
  final String code;
  final String name;
  final List<String> members;
  final Map<String, String> memberNames;
  final DateTime createdAt;

  const SharedGarden({
    required this.id,
    required this.code,
    required this.name,
    required this.members,
    required this.memberNames,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'members': members,
      'memberNames': memberNames,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SharedGarden.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseTime(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    final membersList =
        (data['members'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final rawNames = data['memberNames'] as Map<String, dynamic>? ?? {};
    final namesMap = rawNames.map((k, v) => MapEntry(k, v.toString()));

    return SharedGarden(
      id: id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? 'Vườn sẻ chia',
      members: membersList,
      memberNames: namesMap,
      createdAt: parseTime(data['createdAt']),
    );
  }
}

class SharedMoment {
  final String id;
  final String gardenId;
  final String authorId;
  final String authorName;
  final String emotionKey;
  final int intensity;
  final String caption;
  final int slotIndex;
  final int bedIndex;
  final String monthKey;
  final DateTime plantedAt;
  final int waterCount;
  final int sunCount;
  final String? lastInteraction;

  const SharedMoment({
    required this.id,
    required this.gardenId,
    required this.authorId,
    required this.authorName,
    required this.emotionKey,
    required this.intensity,
    required this.caption,
    required this.slotIndex,
    this.bedIndex = 0,
    required this.monthKey,
    required this.plantedAt,
    this.waterCount = 0,
    this.sunCount = 0,
    this.lastInteraction,
  });

  int get appearanceVariant => id.hashCode.abs() % 3;

  SharedMoment copyWith({
    int? waterCount,
    int? sunCount,
    String? lastInteraction,
  }) {
    return SharedMoment(
      id: id,
      gardenId: gardenId,
      authorId: authorId,
      authorName: authorName,
      emotionKey: emotionKey,
      intensity: intensity,
      caption: caption,
      slotIndex: slotIndex,
      bedIndex: bedIndex,
      monthKey: monthKey,
      plantedAt: plantedAt,
      waterCount: waterCount ?? this.waterCount,
      sunCount: sunCount ?? this.sunCount,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gardenId': gardenId,
      'authorId': authorId,
      'authorName': authorName,
      'emotionKey': emotionKey,
      'intensity': intensity,
      'caption': caption,
      'slotIndex': slotIndex,
      'bedIndex': bedIndex,
      'monthKey': monthKey,
      'plantedAt': plantedAt.toIso8601String(),
      'waterCount': waterCount,
      'sunCount': sunCount,
      'lastInteraction': lastInteraction,
    };
  }

  factory SharedMoment.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseTime(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return SharedMoment(
      id: id,
      gardenId: data['gardenId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Bạn đồng hành',
      emotionKey: data['emotionKey'] as String? ?? 'happy',
      intensity: (data['intensity'] as num?)?.toInt() ?? 3,
      caption: data['caption'] as String? ?? '',
      slotIndex: (data['slotIndex'] as num?)?.toInt() ?? 0,
      bedIndex: (data['bedIndex'] as num?)?.toInt() ?? 0,
      monthKey: data['monthKey'] as String? ?? '',
      plantedAt: parseTime(data['plantedAt']),
      waterCount: (data['waterCount'] as num?)?.toInt() ?? 0,
      sunCount: (data['sunCount'] as num?)?.toInt() ?? 0,
      lastInteraction: data['lastInteraction'] as String?,
    );
  }
}

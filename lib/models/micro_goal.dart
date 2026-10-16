enum MicroGoalStatus { open, attempted, skipped }

class MicroGoal {
  final String id;
  final String prompt;
  final DateTime createdAt;
  final MicroGoalStatus status;
  final String? followUpNote;

  bool get isCompleted => status == MicroGoalStatus.attempted;

  const MicroGoal({
    required this.id,
    required this.prompt,
    required this.createdAt,
    this.status = MicroGoalStatus.open,
    this.followUpNote,
  });

  MicroGoal copyWith({
    String? id,
    String? prompt,
    DateTime? createdAt,
    MicroGoalStatus? status,
    String? followUpNote,
  }) {
    return MicroGoal(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      followUpNote: followUpNote ?? this.followUpNote,
    );
  }

  Map<String, dynamic> toFirestore({String? userId}) {
    final map = <String, dynamic>{
      'prompt': prompt,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'followUpNote': followUpNote,
    };
    if (userId != null) {
      map['userId'] = userId;
    }
    return map;
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory MicroGoal.fromFirestore(Map<String, dynamic> data, String id) {
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

    MicroGoalStatus parseStatus(dynamic val) {
      if (val == 'attempted') return MicroGoalStatus.attempted;
      if (val == 'skipped') return MicroGoalStatus.skipped;
      return MicroGoalStatus.open;
    }

    return MicroGoal(
      id: id,
      prompt: data['prompt'] as String? ?? '',
      createdAt: parseTime(data['createdAt']),
      status: parseStatus(data['status']),
      followUpNote: data['followUpNote'] as String?,
    );
  }

  factory MicroGoal.fromJson(Map<String, dynamic> json, [String? id]) {
    return MicroGoal.fromFirestore(json, id ?? json['id'] as String? ?? '');
  }
}


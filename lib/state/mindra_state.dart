import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/garden_layout.dart';
import '../models/ai_reflection.dart';
import '../models/badge_item.dart';
import '../models/emotion.dart';
import '../models/garden_moment.dart';
import '../models/journal_entry.dart';
import '../models/micro_goal.dart';
import '../repositories/auth_repository.dart';
import '../repositories/garden_repository.dart';
import '../repositories/journal_repository.dart';
import '../repositories/reflection_repository.dart';

enum DemoScenario { firstLaunch, returning, active }

class MindraState extends ChangeNotifier {
  final AuthRepository _authRepository;
  final JournalRepository _journalRepository;
  final GardenRepository _gardenRepository;
  final ReflectionRepository _reflectionRepository;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<JournalEntry>>? _entriesSubscription;
  StreamSubscription<List<GardenMoment>>? _gardenSubscription;

  String _selectedEmotionKey = 'happy';
  int _currentIntensity = 3;
  int _currentTab = 0;
  DemoScenario _demoScenario = DemoScenario.active;
  final List<JournalEntry> _entries = [];
  final Map<String, AIReflection> _aiReflections = {};
  final List<GardenMoment> _gardenMoments = [];

  MindraState({
    AuthRepository? authRepository,
    JournalRepository? journalRepository,
    GardenRepository? gardenRepository,
    ReflectionRepository? reflectionRepository,
    List<JournalEntry>? initialEntries,
    List<MicroGoal>? initialMicroGoals,
    bool? isAuthenticated,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _journalRepository = journalRepository ?? JournalRepository(),
        _gardenRepository = gardenRepository ?? GardenRepository(),
        _reflectionRepository = reflectionRepository ?? ReflectionRepository() {
    if (initialEntries != null && initialEntries.isNotEmpty) {
      _entries.addAll(initialEntries);
      final entry = _entryForDay(DateTime.now());
      if (entry != null) _selectedEmotionKey = entry.emotionKey;
      _seedGardenFromEntries(_entries.take(8));
      _isAuthenticated = isAuthenticated ?? true;
      _onboardingCompleted = true;
      _userEmail = 'ban@mindra.app';
    } else {
      // 100% REAL DATA MODE: Bỏ toàn bộ mock data, đồng bộ trực tiếp với Firebase
      final user = _authRepository.currentUser;
      if (user != null) {
        _isAuthenticated = isAuthenticated ?? true;
        _onboardingCompleted = true;
        _userEmail = user.email ??
            (user.isAnonymous ? 'Khách ẩn danh' : 'Người dùng');
        _userName = user.displayName ?? '';
        _startFirestoreListeners(user.uid);
      } else {
        _isAuthenticated = isAuthenticated ?? false;
        _onboardingCompleted = false;
        _userEmail = '';
        _userName = '';
      }

      // Lắng nghe thay đổi trạng thái đăng nhập Firebase trong suốt phiên dùng
      _authSubscription = _authRepository.authStateChanges.listen((u) {
        if (u != null) {
          _isAuthenticated = true;
          _userEmail =
              u.email ?? (u.isAnonymous ? 'Khách ẩn danh' : 'Người dùng');
          _userName = u.displayName ?? '';
          _startFirestoreListeners(u.uid);
          notifyListeners();
        } else {
          _isAuthenticated = false;
          _userEmail = '';
          _userName = '';
          _entriesSubscription?.cancel();
          _gardenSubscription?.cancel();
          _entries.clear();
          _gardenMoments.clear();
          _microGoals.clear();
          notifyListeners();
        }
      });
    }

    if (initialMicroGoals != null && initialMicroGoals.isNotEmpty) {
      _microGoals.addAll(initialMicroGoals);
    }
  }

  AuthRepository get authRepository => _authRepository;
  JournalRepository get journalRepository => _journalRepository;
  GardenRepository get gardenRepository => _gardenRepository;
  ReflectionRepository get reflectionRepository => _reflectionRepository;

  String get selectedEmotionKey => _selectedEmotionKey;
  EmotionInfo get selectedEmotion => MindraEmotions.get(_selectedEmotionKey);
  int get currentIntensity => _currentIntensity;
  int get currentTab => _currentTab;
  DemoScenario get demoScenario => _demoScenario;
  List<JournalEntry> get entries => List.unmodifiable(_entries);
  List<GardenMoment> get gardenMoments => List.unmodifiable(_gardenMoments);

  AIReflection? reflectionForEntry(String entryId) => _aiReflections[entryId];

  void cacheAIReflection(String entryId, AIReflection reflection) {
    _aiReflections[entryId] = reflection;
  }

  void updateAIReflection(String entryId, AIReflection reflection) {
    _aiReflections[entryId] = reflection;
    notifyListeners();
  }

  int get totalCheckins => _entries.length;
  bool get checkedInToday => _entryForDay(DateTime.now()) != null;

  int get uniqueCheckinDays {
    return _entries
        .map(
          (entry) => DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          ),
        )
        .toSet()
        .length;
  }

  int get exercisesCompleted =>
      _entries.where((entry) => entry.exerciseDone).length;

  JournalEntry? get todayEntry => _entryForDay(DateTime.now());

  int get consecutiveWeeks {
    final now = DateTime.now();
    var weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    var count = 0;

    while (_entries.any((entry) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      return !date.isBefore(weekStart) &&
          date.isBefore(weekStart.add(const Duration(days: 7)));
    })) {
      count++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    return count;
  }

  double get positivePercentage {
    if (_entries.isEmpty) return 70.0;
    final positiveCount = _entries.where((e) {
      final emo = MindraEmotions.get(e.emotionKey);
      return emo.category == EmotionCategory.positive ||
          emo.category == EmotionCategory.calm;
    }).length;
    return (positiveCount / _entries.length * 100);
  }

  List<JournalEntry> get thisWeekEntries {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return _entries.where((e) => !e.timestamp.isBefore(weekStart)).toList();
  }

  int get checkinDaysThisWeek {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return _entries
        .where((e) => !e.timestamp.isBefore(weekStart))
        .map(
          (e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day),
        )
        .toSet()
        .length;
  }

  double get averageIntensityThisWeek {
    final list = thisWeekEntries.isNotEmpty ? thisWeekEntries : _entries;
    if (list.isEmpty) return 0.0;
    final sum = list.map((e) => e.intensity).reduce((a, b) => a + b);
    return sum / list.length;
  }

  String? get dominantEmotionThisWeek {
    final list = thisWeekEntries.isNotEmpty ? thisWeekEntries : _entries;
    if (list.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in list) {
      counts[e.emotionKey] = (counts[e.emotionKey] ?? 0) + 1;
    }
    var bestKey = list.first.emotionKey;
    var bestCount = 0;
    counts.forEach((k, v) {
      if (v > bestCount) {
        bestCount = v;
        bestKey = k;
      }
    });
    return bestKey;
  }

  String? get dominantTriggerThisWeek {
    final list = thisWeekEntries.isNotEmpty ? thisWeekEntries : _entries;
    if (list.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in list) {
      if (e.trigger.isNotEmpty && e.trigger != 'other') {
        counts[e.trigger] = (counts[e.trigger] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    var bestTrigger = counts.keys.first;
    var bestCount = 0;
    counts.forEach((k, v) {
      if (v > bestCount) {
        bestCount = v;
        bestTrigger = k;
      }
    });
    return bestTrigger;
  }

  Map<String, double> get emotionBreakdown {
    if (_entries.isEmpty) return {};
    final counts = <String, int>{};
    for (final e in _entries) {
      counts[e.emotionKey] = (counts[e.emotionKey] ?? 0) + 1;
    }
    final total = _entries.length;
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return {for (var k in sortedKeys) k: counts[k]! / total};
  }

  JournalEntry? get latestExerciseWithFeedback {
    try {
      return _entries.firstWhere(
        (e) => e.exerciseDone && e.afterIntensity != null,
      );
    } catch (_) {
      return null;
    }
  }

  void selectEmotion(String key) {
    if (_selectedEmotionKey != key) {
      _selectedEmotionKey = key;
      notifyListeners();
    }
  }

  void setIntensity(int intensity) {
    _currentIntensity = intensity;
    notifyListeners();
  }

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }

  void addEntry(JournalEntry entry) {
    _entries.insert(0, entry);
    notifyListeners();
    _journalRepository
        .saveEntry(entry, userId: _authRepository.currentUserId)
        .catchError((e) {
      debugPrint('MindraState: Error syncing addEntry to Firestore ($e)');
    });
  }

  void updateEntry(JournalEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      notifyListeners();
      _journalRepository
          .saveEntry(entry, userId: _authRepository.currentUserId)
          .catchError((e) {
        debugPrint('MindraState: Error syncing updateEntry to Firestore ($e)');
      });
    }
  }

  void removeEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    _gardenMoments.removeWhere((moment) => moment.entryId == id);
    notifyListeners();
    _journalRepository
        .deleteEntry(id, userId: _authRepository.currentUserId)
        .catchError((e) {
      debugPrint('MindraState: Error syncing removeEntry to Firestore ($e)');
    });
  }

  JournalEntry? entryById(String id) {
    try {
      return _entries.firstWhere((entry) => entry.id == id);
    } catch (_) {
      return null;
    }
  }

  GardenMoment? momentForEntry(String entryId) {
    try {
      return _gardenMoments.firstWhere((moment) => moment.entryId == entryId);
    } catch (_) {
      return null;
    }
  }

  bool isPlanted(String entryId) => momentForEntry(entryId) != null;

  String currentGardenMonthKey() => GardenMoment.monthKeyFor(DateTime.now());

  List<String> gardenMonthKeys() {
    final keys = _gardenMoments.map((moment) => moment.monthKey).toSet();
    keys.add(currentGardenMonthKey());
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<GardenMoment> momentsInMonth(String monthKey) {
    final moments = _gardenMoments
        .where((moment) => moment.monthKey == monthKey)
        .toList();
    moments.sort((a, b) {
      final bed = a.bedIndex.compareTo(b.bedIndex);
      if (bed != 0) return bed;
      return a.slotIndex.compareTo(b.slotIndex);
    });
    return moments;
  }

  List<GardenBedGroup> bedsInMonth(String monthKey) {
    final grouped = <int, List<GardenMoment>>{};
    for (final moment in momentsInMonth(monthKey)) {
      grouped.putIfAbsent(moment.bedIndex, () => []).add(moment);
    }
    if (grouped.isEmpty) {
      return const [GardenBedGroup(bedIndex: 0, moments: [])];
    }
    final beds = grouped.keys.toList()..sort();
    return [
      for (final bedIndex in beds)
        GardenBedGroup(bedIndex: bedIndex, moments: grouped[bedIndex]!),
    ];
  }

  GardenMoment? plantMoment(String entryId, {bool notify = true}) {
    final entry = entryById(entryId);
    if (entry == null) return null;
    final existing = momentForEntry(entryId);
    if (existing != null) return existing;

    final monthKey = GardenMoment.monthKeyFor(entry.timestamp);
    final placement = GardenLayout.nextFreePlacement(
      momentsInMonth(monthKey).map(
        (moment) => (bedIndex: moment.bedIndex, slotIndex: moment.slotIndex),
      ),
    );
    final moment = GardenMoment(
      id: 'garden-$entryId',
      entryId: entryId,
      monthKey: monthKey,
      bedIndex: placement.bedIndex,
      slotIndex: placement.slotIndex,
      plantedAt: DateTime.now(),
      appearanceVariant: entryId.hashCode.abs() % 3,
    );
    _gardenMoments.add(moment);
    _gardenRepository
        .saveMoment(moment, userId: _authRepository.currentUserId)
        .catchError((e) {
      debugPrint('MindraState: Error syncing moment to Firestore ($e)');
    });
    if (notify) notifyListeners();
    return moment;
  }

  void removeMoment(String momentId) {
    _gardenMoments.removeWhere((moment) => moment.id == momentId);
    notifyListeners();
  }

  void _seedGardenFromEntries(Iterable<JournalEntry> entries) {
    _gardenMoments.clear();
    for (final entry in entries) {
      plantMoment(entry.id, notify: false);
    }
  }

  void completeExercise({
    required String exerciseId,
    String note = '',
    String? afterEmotionKey,
    int? afterIntensity,
    int? usefulnessRating,
    int? easeRating,
    String? repeatPreference,
  }) {
    final today = _entryForDay(DateTime.now());
    if (today != null) {
      final index = _entries.indexWhere((entry) => entry.id == today.id);
      if (index != -1) {
        _entries[index] = today.copyWith(
          exerciseId: exerciseId,
          exerciseDone: true,
          thought: note.isNotEmpty ? note : today.thought,
          afterEmotionKey: afterEmotionKey,
          afterIntensity: afterIntensity,
          usefulnessRating: usefulnessRating,
          easeRating: easeRating,
          repeatPreference: repeatPreference,
        );
        notifyListeners();
        return;
      }
    }

    addEntry(
      JournalEntry(
        id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        emotionKey: _selectedEmotionKey,
        intensity: _currentIntensity,
        thought: note,
        exerciseId: exerciseId,
        exerciseDone: true,
        afterEmotionKey: afterEmotionKey,
        afterIntensity: afterIntensity,
        usefulnessRating: usefulnessRating,
        easeRating: easeRating,
        repeatPreference: repeatPreference,
      ),
    );
  }

  void saveCurrentCheckin({String? note}) {
    final entry = JournalEntry(
      id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      emotionKey: _selectedEmotionKey,
      intensity: _currentIntensity,
      situation: note ?? '',
      thought: selectedEmotion.defaultThought,
    );
    addEntry(entry);
  }

  // Settings & Privacy State (S19, S20, S21)
  bool _aiConsent = true;
  bool get aiConsent => _aiConsent;

  bool _lowStimulationMode = false;
  bool get lowStimulationMode => _lowStimulationMode;

  bool _gardenVisible = true;
  bool get gardenVisible => _gardenVisible;

  bool _appLockEnabled = false;
  bool get appLockEnabled => _appLockEnabled;

  bool _reminderEnabled = true;
  bool get reminderEnabled => _reminderEnabled;

  String _reminderTime = '21:00';
  String get reminderTime => _reminderTime;

  final List<String> _userGoals = [
    'Hiểu cảm xúc của tôi',
    'Giảm căng thẳng hằng ngày',
  ];
  List<String> get userGoals => List.unmodifiable(_userGoals);

  Map<String, String>? _weeklyReview;
  Map<String, String>? get weeklyReview => _weeklyReview;

  void setAiConsent(bool val) {
    _aiConsent = val;
    notifyListeners();
  }

  void setLowStimulationMode(bool val) {
    _lowStimulationMode = val;
    notifyListeners();
  }

  void setGardenVisible(bool val) {
    _gardenVisible = val;
    notifyListeners();
  }

  void setAppLockEnabled(bool val) {
    _appLockEnabled = val;
    notifyListeners();
  }

  void setReminderEnabled(bool val) {
    _reminderEnabled = val;
    notifyListeners();
  }

  void setReminderTime(String val) {
    _reminderTime = val;
    notifyListeners();
  }

  void toggleGoal(String goal) {
    if (_userGoals.contains(goal)) {
      if (_userGoals.length > 1) {
        _userGoals.remove(goal);
      }
    } else {
      _userGoals.add(goal);
    }
    notifyListeners();
  }

  void saveWeeklyReview({
    required String mostFrequent,
    required String helped,
    required String nextWeek,
  }) {
    _weeklyReview = {
      'mostFrequent': mostFrequent,
      'helped': helped,
      'nextWeek': nextWeek,
      'date': DateTime.now().toIso8601String(),
    };
    notifyListeners();
  }

  void clearAllData() {
    _entries.clear();
    _gardenMoments.clear();
    _weeklyReview = null;
    notifyListeners();
  }

  // Onboarding (S01–S04)
  bool _onboardingCompleted = false;
  bool get onboardingCompleted => _onboardingCompleted;

  void completeOnboarding() {
    _onboardingCompleted = true;
    notifyListeners();
  }

  void resetOnboarding() {
    _onboardingCompleted = false;
    notifyListeners();
  }

  // Micro-Goals (S11, S11-G)
  final List<MicroGoal> _microGoals = [];
  List<MicroGoal> get microGoals => List.unmodifiable(_microGoals);

  void addMicroGoal(String prompt) {
    if (prompt.trim().isEmpty) return;
    _microGoals.insert(
      0,
      MicroGoal(
        id: 'mg-${DateTime.now().millisecondsSinceEpoch}',
        prompt: prompt.trim(),
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void updateMicroGoalFollowUp(
    String id, {
    required MicroGoalStatus status,
    String? note,
  }) {
    final index = _microGoals.indexWhere((g) => g.id == id);
    if (index != -1) {
      _microGoals[index] = _microGoals[index].copyWith(
        status: status,
        followUpNote: note,
      );
      notifyListeners();
    }
  }

  // Badges (S18)
  List<BadgeItem> get badges {
    final totalDays = uniqueCheckinDays;
    final totalEx = exercisesCompleted;
    final hasEntry = _entries.isNotEmpty;

    return [
      BadgeItem(
        id: 'badge-1',
        title: 'Phản tư đầu tiên',
        description: 'Hoàn thành check-in cảm xúc đầu tiên của bạn.',
        iconEmoji: '🌟',
        isUnlocked: hasEntry,
        progress: hasEntry ? 1.0 : 0.0,
      ),
      BadgeItem(
        id: 'badge-2',
        title: 'Có mặt 3 ngày',
        description: 'Duy trì check-in trong 3 ngày để nhận diện cảm xúc.',
        iconEmoji: '📅',
        isUnlocked: totalDays >= 3,
        progress: (totalDays / 3.0).clamp(0.0, 1.0),
      ),
      BadgeItem(
        id: 'badge-3',
        title: 'Một tuần nhận biết',
        description: 'Đã check-in đủ 7 ngày, xây dựng thói quen chánh niệm.',
        iconEmoji: '🌿',
        isUnlocked: totalDays >= 7,
        progress: (totalDays / 7.0).clamp(0.0, 1.0),
      ),
      BadgeItem(
        id: 'badge-4',
        title: 'Thử công cụ mới',
        description: 'Hoàn thành bài tập điều hòa cảm xúc đầu tiên.',
        iconEmoji: '🧘',
        isUnlocked: totalEx >= 1,
        progress: totalEx >= 1 ? 1.0 : 0.0,
      ),
    ];
  }

  // Authentication (S01.5)
  bool _isAuthenticated = false;
  String _userEmail = '';
  String _userName = '';

  bool get isAuthenticated => _isAuthenticated;
  String get userEmail => _userEmail;

  String get userName {
    if (_userName.trim().isNotEmpty) return _userName.trim();
    if (_userEmail.isNotEmpty && _userEmail.contains('@')) {
      final prefix = _userEmail.split('@').first;
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return _userEmail.isNotEmpty ? _userEmail : 'Bạn';
  }

  String get userInitial {
    final name = userName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'B';
  }

  void authenticate([String? email, String? name]) {
    _isAuthenticated = true;
    if (email != null && email.trim().isNotEmpty) {
      _userEmail = email.trim();
    }
    if (name != null && name.trim().isNotEmpty) {
      _userName = name.trim();
    } else if (email != null && email.contains('@')) {
      final prefix = email.split('@').first;
      _userName = prefix.isNotEmpty
          ? prefix[0].toUpperCase() + prefix.substring(1)
          : '';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();
    // Sign out từ Firebase (fire-and-forget nếu lỗi)
    await authRepository.signOut();
    _isAuthenticated = false;
    _onboardingCompleted = true;
    _demoScenario = DemoScenario.firstLaunch;
    _entries.clear();
    _gardenMoments.clear();
    _microGoals.clear();
    _userEmail = '';
    _userName = '';
    notifyListeners();
  }

  void applyDemoScenario(DemoScenario scenario) {
    _demoScenario = scenario;
    _currentTab = 0;
    _aiReflections.clear();
    _gardenMoments.clear();
    _weeklyReview = null;
    _microGoals
      ..clear()
      ..add(
        MicroGoal(
          id: 'mg-1',
          prompt: 'Khi cảm thấy căng thẳng dồn dập, tôi sẽ dừng lại 30 giây và hít thở sâu 3 nhịp.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

    switch (scenario) {
      case DemoScenario.firstLaunch:
        _entries.clear();
        _gardenMoments.clear();
        _onboardingCompleted = false;
        _isAuthenticated = false;
        _selectedEmotionKey = 'calm';
        _currentIntensity = 3;
        break;
      case DemoScenario.returning:
      case DemoScenario.active:
        _entries.clear();
        _gardenMoments.clear();
        _onboardingCompleted = true;
        _isAuthenticated = true;
        _selectedEmotionKey = 'calm';
        _currentIntensity = 3;
        break;
    }
    notifyListeners();
  }

  JournalEntry? _entryForDay(DateTime day) {
    return _entries.where((entry) {
      return entry.timestamp.year == day.year &&
          entry.timestamp.month == day.month &&
          entry.timestamp.day == day.day;
    }).firstOrNull;
  }

  Future<AIReflection> fetchOrGenerateAIReflection(JournalEntry entry) async {
    final cached = reflectionForEntry(entry.id);
    if (cached != null) return cached;
    final generated = await _reflectionRepository.generateReflection(
      emotionKey: entry.emotionKey,
      intensity: entry.intensity,
      situation: entry.situation,
      thought: entry.thought,
    );
    cacheAIReflection(entry.id, generated);
    notifyListeners();
    return generated;
  }

  void _startFirestoreListeners(String userId) {
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();

    _entriesSubscription =
        _journalRepository.watchEntries(userId: userId).listen(
      (remoteEntries) {
        _entries
          ..clear()
          ..addAll(remoteEntries);
        final today = _entryForDay(DateTime.now());
        if (today != null) _selectedEmotionKey = today.emotionKey;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('MindraState: Error watching entries ($e)');
      },
    );

    _gardenSubscription =
        _gardenRepository.watchMoments(userId: userId).listen(
      (remoteMoments) {
        _gardenMoments
          ..clear()
          ..addAll(remoteMoments);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('MindraState: Error watching moments ($e)');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();
    super.dispose();
  }

  Future<void> syncFromFirestore() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return;
    try {
      final remoteEntries = await _journalRepository.fetchEntries(userId: uid);
      if (remoteEntries.isNotEmpty) {
        _entries
          ..clear()
          ..addAll(remoteEntries);
      }
      final remoteMoments = await _gardenRepository.fetchMoments(userId: uid);
      if (remoteMoments.isNotEmpty) {
        _gardenMoments
          ..clear()
          ..addAll(remoteMoments);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('MindraState: Error in syncFromFirestore ($e)');
    }
  }
}

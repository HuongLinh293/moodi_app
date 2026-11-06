import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/garden_layout.dart';
import '../core/device_auth_service.dart';
import '../core/reminder_service.dart';
import '../models/ai_reflection.dart';
import '../models/badge_item.dart';
import '../models/emotion.dart';
import '../models/garden_moment.dart';
import '../models/journal_entry.dart';
import '../models/micro_goal.dart';
import '../models/practice_record.dart';
import '../repositories/practice_repository.dart';
import '../models/shared_garden.dart';
import '../repositories/auth_repository.dart';
import '../repositories/garden_repository.dart';
import '../repositories/journal_repository.dart';
import '../repositories/journal_cache.dart';
import '../repositories/reflection_repository.dart';
import '../repositories/shared_garden_repository.dart';
import '../repositories/user_repository.dart';

enum EntrySyncStatus { pending, synced, failed, sessionOnly }

enum DemoScenario { firstLaunch, returning, active }

class MindraState extends ChangeNotifier {
  final AuthRepository _authRepository;
  final JournalRepository _journalRepository;
  final GardenRepository _gardenRepository;
  final ReflectionRepository _reflectionRepository;
  final SharedGardenRepository _sharedGardenRepository;
  final UserRepository _userRepository;
  final ReminderService _reminderService;
  final JournalCache _journalCache;
  final PracticeRepository _practiceRepository;
  final DeviceAuthService _deviceAuth;

  StreamSubscription<AuthUser?>? _authSubscription;
  StreamSubscription<List<JournalEntry>>? _entriesSubscription;
  StreamSubscription<List<GardenMoment>>? _gardenSubscription;
  StreamSubscription<SharedGarden?>? _sharedGardenSubscription;
  StreamSubscription<List<SharedMoment>>? _sharedMomentsSubscription;

  String _selectedEmotionKey = 'happy';
  int _currentIntensity = 3;
  int _currentTab = 0;
  DemoScenario _demoScenario = DemoScenario.active;
  final List<JournalEntry> _entries = [];
  final Map<String, AIReflection> _aiReflections = {};
  // Yêu cầu tạo phản tư đang chạy theo entry, để mở lại màn hình không gửi
  // trùng (tốn phí AI gấp đôi và chạm unique index ở server).
  final Map<String, Future<AIReflection>> _reflectionRequests = {};
  // Tăng khi nội dung entry đổi; kết quả của yêu cầu cũ bị bỏ qua.
  final Map<String, int> _reflectionVersions = {};
  final List<GardenMoment> _gardenMoments = [];

  // Shared Garden State
  bool _isSharedGardenMode = false;
  bool get isSharedGardenMode => _isSharedGardenMode;
  SharedGarden? _sharedGarden;
  SharedGarden? get sharedGarden => _sharedGarden;
  final List<SharedMoment> _sharedMoments = [];
  List<SharedMoment> get sharedMoments => List.unmodifiable(_sharedMoments);

  MindraState({
    AuthRepository? authRepository,
    JournalRepository? journalRepository,
    GardenRepository? gardenRepository,
    ReflectionRepository? reflectionRepository,
    SharedGardenRepository? sharedGardenRepository,
    UserRepository? userRepository,
    ReminderService? reminderService,
    JournalCache? journalCache,
    PracticeRepository? practiceRepository,
    DeviceAuthService? deviceAuth,
    List<JournalEntry>? initialEntries,
    List<MicroGoal>? initialMicroGoals,
    bool? isAuthenticated,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _journalRepository = journalRepository ?? JournalRepository(),
       _gardenRepository = gardenRepository ?? GardenRepository(),
       _reflectionRepository = reflectionRepository ?? ReflectionRepository(),
       _sharedGardenRepository =
           sharedGardenRepository ?? SharedGardenRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _deviceAuth = deviceAuth ?? DeviceAuthService(),
       _practiceRepository = practiceRepository ?? PracticeRepository(),
       _journalCache = journalCache ?? JournalCache(),
       _reminderService = reminderService ?? ReminderService() {
    if (initialEntries != null && initialEntries.isNotEmpty) {
      _entries.addAll(initialEntries);
      final entry = _entryForDay(DateTime.now());
      if (entry != null) _selectedEmotionKey = entry.emotionKey;
      _seedGardenFromEntries(_entries.take(8));
      _isAuthenticated = isAuthenticated ?? true;
      _onboardingCompleted = true;
      _userEmail = 'ban@mindra.app';
    } else {
      // 100% REAL DATA MODE: Bỏ toàn bộ mock data, đồng bộ trực tiếp với API
      final user = _authRepository.currentUser;
      if (user != null) {
        _isAuthenticated = isAuthenticated ?? true;
        _onboardingCompleted = true;
        _userEmail = user.email;
        _userName = user.displayName ?? '';
        _startApiListeners(user.id);
      } else {
        _isAuthenticated = isAuthenticated ?? false;
        _onboardingCompleted = false;
        _userEmail = '';
        _userName = '';
      }

      // Lắng nghe thay đổi trạng thái đăng nhập API trong suốt phiên dùng
      _authSubscription = _authRepository.authStateChanges.listen((u) {
        if (_disposed) return;
        _sessionRevision++;
        _resetSessionUi();
        _entriesSubscription?.cancel();
        _gardenSubscription?.cancel();
        _clearSharedSession();
        _entries.clear();
        _practiceRecords.clear();
        _pendingPracticeIds.clear();
        _gardenMoments.clear();
        _aiReflections.clear();
        _unsentFeedback.clear();
        _reflectionRequests.clear();
        _weeklyReview = null;
        _microGoals.clear();
        _entrySync.clear();
        _entryWriteVersions.clear();
        _awaitingRemoteEntryIds.clear();
        _remoteMisses.clear();
        if (u != null) {
          _isAuthenticated = true;
          _userEmail = u.email;
          _userName = u.displayName ?? '';
          _startApiListeners(u.id);
          notifyListeners();
        } else {
          _clearSharedSession();
          _isAuthenticated = false;
          _userEmail = '';
          _userName = '';
          _entriesSubscription?.cancel();
          _gardenSubscription?.cancel();
          _entrySync.clear();
          _entryWriteVersions.clear();
          _awaitingRemoteEntryIds.clear();
        _remoteMisses.clear();
          _entries.clear();
          _gardenMoments.clear();
          _microGoals.clear();
          notifyListeners();
        }
      });
      if (user == null && isAuthenticated == null) _restoreSession();
    }

    if (initialMicroGoals != null && initialMicroGoals.isNotEmpty) {
      _microGoals.addAll(initialMicroGoals);
    }
  }

  bool _hasChosenEmotion = false;
  bool get hasChosenEmotion => _hasChosenEmotion;
  bool get isGuest => _authRepository.currentUser?.isAnonymous ?? false;
  int _personalSpaceSection = 0;
  int get personalSpaceSection => _personalSpaceSection;
  void setPersonalSpaceSection(int section) {
    _personalSpaceSection = section.clamp(0, 1);
    notifyListeners();
  }

  DateTime? _journalFocusDate;
  DateTime? get journalFocusDate => _journalFocusDate;
  int _journalFocusSeq = 0;
  int get journalFocusSeq => _journalFocusSeq;
  void openJournal({String? entryId}) {
    _journalFocusDate = entryId == null
        ? DateTime.now()
        : entryById(entryId)?.timestamp ?? DateTime.now();
    _journalFocusSeq++;
    _personalSpaceSection = 0;
    setTab(1);
    notifyListeners();
  }

  // Tháng mà khu vườn cần hiển thị khi được mở; seq tăng mỗi lần yêu cầu để
  // GardenView vẫn nhảy tháng dù cùng monthKey được yêu cầu lần nữa.
  String? _gardenFocusMonthKey;
  String? get gardenFocusMonthKey => _gardenFocusMonthKey;
  int _gardenFocusSeq = 0;
  int get gardenFocusSeq => _gardenFocusSeq;

  void openGarden({String? monthKey}) {
    _personalSpaceSection = 1;
    _gardenFocusMonthKey = monthKey;
    _gardenFocusSeq++;
    setTab(1);
    notifyListeners();
  }

  bool _isDemoSharedGarden = false;
  bool get isDemoSharedGarden => _isDemoSharedGarden;
  String get sharedDisplayNameSuggestion =>
      _userName.isEmpty ? 'Bạn' : _userName;
  bool isSharedPlanted(String entryId) =>
      _sharedMoments.any((m) => m.id == '${currentUserId}_$entryId');
  Future<void> removeSharedMoment(String momentId) async {
    _requireUserId();
    final garden = _sharedGarden;
    if (garden == null) throw StateError('Hãy chọn một khu vườn.');
    final revision = _sessionRevision;
    await _sharedGardenRepository.removeMoment(garden.id, momentId);
    if (_disposed || revision != _sessionRevision) return;
    _sharedMoments.removeWhere((m) => m.id == momentId);
    notifyListeners();
  }

  // Đang đổi refresh token đã lưu trong Keychain/Keystore lấy phiên mới.
  bool _restoringSession = false;
  bool get isRestoringSession => _restoringSession;

  Future<void> _restoreSession() async {
    _restoringSession = true;
    try {
      final restored = await _authRepository.restoreSession();
      if (restored && !_disposed) {
        _onboardingCompleted = true;
        _savePreferences();
      }
    } catch (e) {
      debugPrint('MindraState: restoreSession failed ($e)');
    } finally {
      _restoringSession = false;
      if (!_disposed) notifyListeners();
    }
  }

  ({bool google, bool apple})? _socialProviders;
  ({bool google, bool apple}) get socialProviders =>
      _socialProviders ?? (google: false, apple: false);

  bool _socialProvidersUnavailable = false;
  bool get socialProvidersUnavailable => _socialProvidersUnavailable;
  bool _loadingSocialProviders = false;
  bool get loadingSocialProviders => _loadingSocialProviders;

  /// A connection failure is distinct from an explicitly disabled provider.
  Future<void> loadSocialProviders() async {
    if (_loadingSocialProviders) return;
    _loadingSocialProviders = true;
    final social = _authRepository.socialSignIn;
    try {
      final server = await _authRepository.socialProviders();
      final apple = server.apple && await social.appleAvailable();
      if (_disposed) return;
      _socialProviders = (
        google: server.google && social.googleConfigured,
        apple: apple,
      );
      _socialProvidersUnavailable = false;
    } catch (_) {
      if (_disposed) return;
      _socialProvidersUnavailable = true;
      // Keep known configuration through transient outages. The backend still
      // validates all sign-ins; showing the button grants no authentication.
      _socialProviders ??= (
        google: social.googleConfigured,
        apple: await social.appleAvailable(),
      );
    } finally {
      _loadingSocialProviders = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> signInWithGoogle() =>
      _socialLogin(_authRepository.signInWithGoogle);

  Future<void> signInWithApple() =>
      _socialLogin(_authRepository.signInWithApple);

  Future<void> _socialLogin(Future<AuthResponse?> Function() signIn) async {
    _isLoading = true;
    notifyListeners();
    try {
      // null = người dùng huỷ, không phải lỗi.
      await signIn();
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  int _sessionRevision = 0;
  int get sessionRevision => _sessionRevision;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authRepository.signInWithEmailPassword(
        email,
        password,
      );
      if (result == null) throw StateError('Không thể đăng nhập.');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authRepository.registerWithEmailPassword(
        email,
        password,
        displayName: displayName,
      );
      if (result == null) throw StateError('Không thể tạo tài khoản.');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> deleteAllUserData() async {
    await flushLocalData();
    await Future.wait(List.of(_pendingWrites));
    await _practiceQueue;
    final uid = _requireUserId();
    final revision = _sessionRevision;
    if (_sharedGarden != null) {
      await _sharedGardenRepository.removeMyMoments(_sharedGarden!.id);
    }
    await _journalRepository.deleteAllEntries(userId: uid);
    await _gardenRepository.deleteAllMoments(userId: uid);
    if (!_disposed && revision == _sessionRevision) {
      clearAllData();
      await flushLocalData();
      if (cacheWriteFailed) {
        throw StateError('Dữ liệu trên server đã xóa nhưng chưa xóa được bản trên máy. Hãy giữ app mở và thử lại.');
      }
    }
  }

  AuthRepository get authRepository => _authRepository;
  JournalRepository get journalRepository => _journalRepository;
  GardenRepository get gardenRepository => _gardenRepository;
  ReflectionRepository get reflectionRepository => _reflectionRepository;
  SharedGardenRepository get sharedGardenRepository => _sharedGardenRepository;
  String? get currentUserId => _authRepository.currentUserId;

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
    reflection = reflection.copyWith(
      id: reflection.id ?? _aiReflections[entryId]?.id,
    );
    _aiReflections[entryId] = reflection;
    if (reflection.userFeedback != null) _unsentFeedback.add(entryId);
    _saveUserContent();
    unawaited(_sendReflectionFeedback(entryId, reflection));
    notifyListeners();
  }

  // Phản hồi phản tư chưa gửi được lên server; chỉ gửi lại những cái này.
  final Set<String> _unsentFeedback = {};
  void _resendFeedback() {
    for (final id in List.of(_unsentFeedback)) {
      final r = _aiReflections[id];
      if (r == null) {
        _unsentFeedback.remove(id);
      } else {
        unawaited(_sendReflectionFeedback(id, r));
      }
    }
  }

  Future<void> _sendReflectionFeedback(
    String entryId,
    AIReflection reflection,
  ) async {
    final uid = currentUserId;
    final revision = _sessionRevision;
    if (uid == null ||
        reflection.id == null ||
        reflection.userFeedback == null) {
      return;
    }
    try {
      final edits = Map<String, dynamic>.of(reflection.toJson())
        ..removeWhere(
          (k, _) => [
            'id',
            'source',
            'safetyFlag',
            'safetyReason',
            'userFeedback',
          ].contains(k),
        );
      await _reflectionRepository.saveReflectionFeedback(
        reflectionId: reflection.id!,
        feedback: reflection.userFeedback!,
        helpful: reflection.userFeedback == 'accurate',
        edits: edits,
      );
      if (!_disposed &&
          currentUserId == uid &&
          revision == _sessionRevision &&
          identical(_aiReflections[entryId], reflection)) {
        _unsentFeedback.remove(entryId);
        _saveUserContent();
      }
    } catch (_) {
      if (!_disposed && currentUserId == uid && revision == _sessionRevision) {
        _personalDataError = 'Chỉnh sửa phản tư được giữ trên máy, chưa gửi được phản hồi. Hãy thử cập nhật lại.';
        notifyListeners();
      }
    }
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
      _practiceRecords.length +
      _entries.where((entry) => entry.exerciseDone).length;
  int get practicesThisWeek {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return _practiceRecords
            .where(
              (r) => !r.timestamp.isBefore(start) && r.timestamp.isBefore(end),
            )
            .length +
        thisWeekEntries.where((e) => e.exerciseDone).length;
  }

  final List<PracticeRecord> _practiceRecords = [];
  final Set<String> _pendingPracticeIds = {};
  Future<void> _practiceQueue = Future.value();
  List<PracticeRecord> get practiceRecords =>
      List.unmodifiable(_practiceRecords);

  JournalEntry? get todayEntry => _entryForDay(DateTime.now());

  int get consecutiveDays {
    final days = _entries
        .map(
          (entry) => DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          ),
        )
        .toSet();
    if (days.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var cursor = days.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

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
    final list = thisWeekEntries;
    if (list.isEmpty) return 0.0;
    final sum = list.map((e) => e.intensity).reduce((a, b) => a + b);
    return sum / list.length;
  }

  String? get dominantEmotionThisWeek {
    final list = thisWeekEntries;
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
    final list = thisWeekEntries;
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
    final record = _practiceRecords
        .where(
          (r) =>
              r.beforeIntensity != null &&
              r.afterIntensity != null &&
              r.beforeEmotionKey != null,
        )
        .firstOrNull;
    if (record != null) {
      return JournalEntry(
        id: record.id,
        timestamp: record.timestamp,
        emotionKey: record.beforeEmotionKey!,
        intensity: record.beforeIntensity!,
        exerciseDone: true,
        exerciseId: record.exerciseId,
        afterEmotionKey: record.afterEmotionKey,
        afterIntensity: record.afterIntensity,
        usefulnessRating: record.usefulnessRating,
        easeRating: record.easeRating,
        repeatPreference: record.repeatPreference,
      );
    }
    try {
      return _entries.firstWhere(
        (e) => e.exerciseDone && e.afterIntensity != null,
      );
    } catch (_) {
      return null;
    }
  }

  void selectEmotion(String key) {
    final changed = !_hasChosenEmotion || _selectedEmotionKey != key;
    _hasChosenEmotion = true;
    if (changed) {
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

  bool _loadingPersonalData = false;
  bool get loadingPersonalData => _loadingPersonalData;
  String? _personalDataError;
  String? get personalDataError => _personalDataError;
  DateTime? _lastPersonalSync;
  DateTime? get lastPersonalSync => _lastPersonalSync;
  bool _cacheWriteFailed = false;
  bool _userContentWriteFailed = false;
  bool get cacheWriteFailed => _cacheWriteFailed || _userContentWriteFailed;
  Future<void> _cacheQueue = Future.value();
  Future<void> _userContentQueue = Future.value();
  Future<void>? _restoringJournalCache;
  final Set<String> _durableEntryIds = {};
  bool isEntryOnDevice(String id) => _durableEntryIds.contains(id);

  Future<void> flushLocalData() async {
    await _cacheQueue;
    await _userContentQueue;
    await _preferencesQueue;
    await _consentQueue;
  }

  Future<void> _persistJournal() {
    final uid = currentUserId;
    final revision = _sessionRevision;
    if (uid == null) return Future.value();
    final restoring = _restoringJournalCache;
    if (restoring != null) {
      return restoring.then((_) {
        if (!_disposed &&
            currentUserId == uid &&
            revision == _sessionRevision) {
          return _persistJournal();
        }
      });
    }
    final versions = Map<String, int>.of(_entryWriteVersions);
    final ids = _entries.map((e) => e.id).toSet();
    final snapshot = <String, dynamic>{
      'entries': [
        for (final e in _entries) {...e.toJson(), 'id': e.id},
      ],
      'sync': {for (final e in _entries) e.id: entrySyncStatus(e.id).name},
      'moments': [
        for (final m in _gardenMoments) {...m.toJson(), 'id': m.id},
      ],
      'practice': [for (final record in _practiceRecords) record.toJson()],
      'pendingPractice': _pendingPracticeIds.toList(),
    };
    final write = _cacheQueue.then((_) => _journalCache.write(uid, snapshot));
    _cacheQueue = write
        .then((_) {
          if (!_disposed && currentUserId == uid && revision == _sessionRevision) {
            _cacheWriteFailed = false;
            _durableEntryIds.removeWhere((id) => !ids.contains(id));
            for (final id in ids) {
              if (versions[id] == _entryWriteVersions[id]) {
                _durableEntryIds.add(id);
              }
            }
            notifyListeners();
          }
        })
        .catchError((Object e) {
          if (!_disposed && currentUserId == uid && revision == _sessionRevision) {
            _cacheWriteFailed = true;
            notifyListeners();
          }
        });
    return _cacheQueue;
  }

  Future<void> _loadJournalCache(String uid) async {
    final revision = _sessionRevision;
    try {
      final data = await _journalCache.read(uid);
      if (data == null ||
          _disposed ||
          currentUserId != uid ||
          revision != _sessionRevision) {
        return;
      }
      final statuses = data['sync'] as Map? ?? {};
      for (final raw in (data['practice'] as List? ?? []).whereType<Map>()) {
        final record = PracticeRecord.fromJson(Map<String, dynamic>.from(raw));
        if (!_practiceRecords.any((r) => r.id == record.id)) {
          _practiceRecords.add(record);
        }
      }
      _pendingPracticeIds.addAll(
        (data['pendingPractice'] as List? ?? []).whereType<String>(),
      );
      for (final raw in (data['entries'] as List? ?? []).whereType<Map>()) {
        final e = JournalEntry.fromJson(Map<String, dynamic>.from(raw));
        if (_entries.any((local) => local.id == e.id)) continue;
        _entries.add(e);
        _durableEntryIds.add(e.id);
        _entrySync[e.id] = statuses[e.id] == 'synced'
            ? EntrySyncStatus.synced
            : EntrySyncStatus.failed;
      }
      if (_gardenMoments.isEmpty) {
        _gardenMoments.addAll(
          (data['moments'] as List? ?? []).whereType<Map>().map(
            (m) => GardenMoment.fromJson(Map<String, dynamic>.from(m)),
          ),
        );
      }
      _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (_) {
      if (!_disposed && currentUserId == uid) _cacheWriteFailed = true;
    }
  }

  final Map<String, EntrySyncStatus> _entrySync = {};
  final Map<String, int> _entryWriteVersions = {};
  final Set<String> _awaitingRemoteEntryIds = {};
  final Map<String, int> _remoteMisses = {};

  void _mergeRemoteEntries(List<JournalEntry> remote) {
    final byId = {for (final e in remote) e.id: e};
    _awaitingRemoteEntryIds.removeWhere((id) {
      final local = entryById(id);
      final fresh = byId[id];
      if (local == null) return true;
      if (fresh == null) {
        // Đã ghi xong mà hai lần tải liền server vẫn không có: entry đã bị
        // xóa ở máy khác. Một lần thiếu có thể do lần tải chạy trước lần ghi.
        final settled =
            entrySyncStatus(id) == EntrySyncStatus.synced &&
            !_pendingEntryWrites.containsKey(id);
        final misses = settled ? (_remoteMisses[id] ?? 0) + 1 : 0;
        if (misses < 2) {
          _remoteMisses[id] = misses;
          return false;
        }
        _remoteMisses.remove(id);
        return true;
      }
      _remoteMisses.remove(id);
      final a = local.toJson()..remove('timestamp');
      final b = fresh.toJson()..remove('timestamp');
      return jsonEncode(a) == jsonEncode(b);
    });
    final protected = _entries
        .where(
          (e) =>
              entrySyncStatus(e.id) != EntrySyncStatus.synced ||
              _awaitingRemoteEntryIds.contains(e.id),
        )
        .toList();
    final ids = protected.map((e) => e.id).toSet();
    _entries
      ..clear()
      ..addAll(remote.where((e) => !ids.contains(e.id)))
      ..addAll(protected)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int _entryWriteSequence = 0;
  final Set<Future<void>> _pendingWrites = {};
  // Lệnh ghi đang chạy theo từng entry, để removeEntry chờ chúng xong trước
  // khi xóa — nếu không, lệnh save tới server sau lệnh delete sẽ hồi sinh entry.
  final Map<String, Set<Future<void>>> _pendingEntryWrites = {};
  EntrySyncStatus entrySyncStatus(String id) =>
      _entrySync[id] ?? EntrySyncStatus.synced;
  int get pendingEntryCount =>
      _entrySync.values.where((s) => s == EntrySyncStatus.pending).length;
  int get failedEntryCount =>
      _entrySync.values.where((s) => s == EntrySyncStatus.failed).length;
  int get sessionEntryCount =>
      _entrySync.values.where((s) => s == EntrySyncStatus.sessionOnly).length;

  String entrySaveMessage(String id) => switch (entrySyncStatus(id)) {
    EntrySyncStatus.pending =>
      isEntryOnDevice(id)
          ? 'Đã lưu trên máy. Đang đồng bộ ghi chép…'
          : 'Đang lưu ghi chép…',
    EntrySyncStatus.synced => 'Ghi chép đã được đồng bộ.',
    EntrySyncStatus.failed =>
      isEntryOnDevice(id)
          ? 'Đã lưu trên máy, chưa đồng bộ. Mở Nhật ký để thử lại.'
          : 'Chưa lưu được trên máy hoặc tài khoản. Hãy giữ app mở và thử lại.',
    EntrySyncStatus.sessionOnly =>
      'Ghi chép chỉ có trong phiên này, chưa được lưu lâu dài.',
  };

  void addEntry(JournalEntry entry) {
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.insert(0, entry);
    _queueEntryWrite(entry);
  }

  void updateEntry(JournalEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) return;
    final previous = _entries[index];
    if (previous.situation != entry.situation ||
        previous.thought != entry.thought ||
        previous.emotionKey != entry.emotionKey ||
        previous.intensity != entry.intensity) {
      // Phản tư cũ không còn khớp nội dung; bỏ đi để lần mở sau hỏi lại server
      // (server kiểm tra lại tín hiệu khủng hoảng trên nội dung mới).
      _aiReflections.remove(entry.id);
      _reflectionRequests.remove(entry.id);
      _reflectionVersions[entry.id] = (_reflectionVersions[entry.id] ?? 0) + 1;
    }
    _entries[index] = entry;
    _saveUserContent();
    _queueEntryWrite(entry);
  }

  void _queueEntryWrite(JournalEntry entry) {
    final uid = currentUserId;
    final version = ++_entryWriteSequence;
    _entryWriteVersions[entry.id] = version;
    _durableEntryIds.remove(entry.id);
    _awaitingRemoteEntryIds.add(entry.id);
    _entrySync[entry.id] = uid == null
        ? EntrySyncStatus.sessionOnly
        : EntrySyncStatus.pending;
    notifyListeners();
    if (uid == null) return;
    final revision = _sessionRevision;
    final previousWrites = List<Future<void>>.of(
      _pendingEntryWrites[entry.id] ?? {},
    );
    final cached = _persistJournal();
    final write = () async {
      await cached;
      await Future.wait(previousWrites);
      if (_disposed || currentUserId != uid || revision != _sessionRevision) {
        return;
      }
      await _writeEntry(entry, uid, version);
    }();
    _pendingWrites.add(write);
    final entryWrites = _pendingEntryWrites.putIfAbsent(entry.id, () => {})
      ..add(write);
    unawaited(
      write.whenComplete(() {
        _pendingWrites.remove(write);
        entryWrites.remove(write);
        if (entryWrites.isEmpty) _pendingEntryWrites.remove(entry.id);
      }),
    );
  }

  Future<void> _writeEntry(JournalEntry entry, String uid, int version) async {
    EntrySyncStatus result;
    try {
      await _journalRepository.saveEntry(entry, userId: uid);
      result = EntrySyncStatus.synced;
    } catch (_) {
      result = EntrySyncStatus.failed;
    }
    if (_disposed ||
        currentUserId != uid ||
        _entryWriteVersions[entry.id] != version) {
      return;
    }
    _entrySync[entry.id] = result;
    unawaited(_persistJournal());
    notifyListeners();
  }

  void retryEntrySync() {
    for (final entry in List<JournalEntry>.of(_entries)) {
      if (entrySyncStatus(entry.id) == EntrySyncStatus.failed ||
          entrySyncStatus(entry.id) == EntrySyncStatus.sessionOnly) {
        _queueEntryWrite(entry);
      }
    }
  }

  Future<void> removeEntry(String id) async {
    final uid = _authRepository.currentUserId;
    final pending = _pendingEntryWrites[id];
    if (pending != null) await Future.wait(List.of(pending));
    if (uid != null) {
      if (isSharedPlanted(id)) await removeSharedMoment('${uid}_$id');
      await _journalRepository.deleteEntry(id, userId: uid);
    }
    if (_disposed || _authRepository.currentUserId != uid) return;
    _entrySync.remove(id);
    _entryWriteVersions.remove(id);
    _awaitingRemoteEntryIds.remove(id);
    _entries.removeWhere((e) => e.id == id);
    _practiceRecords.removeWhere((r) => r.sourceEntryId == id);
    _pendingPracticeIds.removeWhere(
      (id) => !_practiceRecords.any((r) => r.id == id),
    );
    _aiReflections.remove(id);
    _reflectionRequests.remove(id);
    _reflectionVersions[id] = (_reflectionVersions[id] ?? 0) + 1;
    _saveUserContent();
    _gardenMoments.removeWhere((moment) => moment.entryId == id);
    _durableEntryIds.remove(id);
    await _persistJournal();
    notifyListeners();
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

  final Map<String, Future<GardenMoment?>> _pendingPlants = {};

  Future<GardenMoment?> plantMoment(String entryId) {
    return _pendingPlants.putIfAbsent(
      entryId,
      () => _plantMoment(entryId).whenComplete(() {
        _pendingPlants.remove(entryId);
      }),
    );
  }

  GardenMoment _newMoment(JournalEntry entry) {
    final entryId = entry.id;
    final monthKey = GardenMoment.monthKeyFor(entry.timestamp);
    final placement = GardenLayout.nextFreePlacement(
      momentsInMonth(monthKey).map(
        (moment) => (bedIndex: moment.bedIndex, slotIndex: moment.slotIndex),
      ),
    );
    return GardenMoment(
      id: 'garden-$entryId',
      entryId: entryId,
      monthKey: monthKey,
      bedIndex: placement.bedIndex,
      slotIndex: placement.slotIndex,
      plantedAt: DateTime.now(),
      appearanceVariant: entryId.hashCode.abs() % 3,
    );
  }

  Future<GardenMoment?> _plantMoment(String entryId) async {
    final entry = entryById(entryId);
    if (entry == null) return null;
    final existing = momentForEntry(entryId);
    if (existing != null) return existing;

    final uid = _authRepository.currentUserId;
    final moment = _newMoment(entry);
    if (uid != null) {
      await _gardenRepository.saveMoment(moment, userId: uid);
    }
    if (_disposed || _authRepository.currentUserId != uid) return null;
    _gardenMoments.removeWhere((m) => m.id == moment.id);
    _gardenMoments.add(moment);
    unawaited(_persistJournal());
    notifyListeners();
    return moment;
  }

  Future<void> removeMoment(String momentId) async {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      await _gardenRepository.deleteMoment(momentId, userId: uid);
    }
    if (_disposed || _authRepository.currentUserId != uid) return;
    _gardenMoments.removeWhere((moment) => moment.id == momentId);
    await _persistJournal();
    notifyListeners();
  }

  void _seedGardenFromEntries(Iterable<JournalEntry> entries) {
    _gardenMoments.clear();
    for (final entry in entries) {
      _gardenMoments.add(_newMoment(entry));
    }
  }

  // ==========================================
  // SHARED GARDEN METHODS (Distributed Sync)
  // ==========================================
  void toggleGardenMode(bool shared) {
    _isSharedGardenMode = shared;
    notifyListeners();
  }

  String? _listeningUserId;
  int _sharedRevision = 0;
  String? _sharedGardenError;
  String? get sharedGardenError => _sharedGardenError;
  bool _sharedGardenLoading = false;
  bool get sharedGardenLoading => _sharedGardenLoading;
  bool _disposed = false;

  void _setSharedGarden(SharedGarden? garden) {
    final changed = _sharedGarden?.id != garden?.id;
    _sharedGarden = garden;
    if (!changed) {
      notifyListeners();
      return;
    }
    final revision = ++_sharedRevision;
    _sharedMomentsSubscription?.cancel();
    _sharedMoments.clear();
    if (garden != null) {
      _sharedMomentsSubscription = _sharedGardenRepository
          .watchMoments(garden.id)
          .listen(
            (moments) {
              if (_disposed || revision != _sharedRevision) return;
              _sharedMoments
                ..clear()
                ..addAll(moments);
              _sharedGardenError = null;
              notifyListeners();
            },
            onError: (Object error) {
              if (_disposed || revision != _sharedRevision) return;
              _sharedMoments.clear();
              _sharedGardenError = 'Không tải được khoảnh khắc. Hãy kiểm tra kết nối và thử lại.';
              notifyListeners();
            },
          );
    }
    notifyListeners();
  }

  void _watchUserGarden(String uid) {
    if (_listeningUserId == uid) return;
    _listeningUserId = uid;
    _sharedGardenSubscription?.cancel();
    _setSharedGarden(null);
    _sharedGardenLoading = true;
    _sharedGardenError = null;
    _sharedGardenSubscription = _sharedGardenRepository
        .watchUserGarden(uid)
        .listen(
          (garden) {
            if (_disposed || _listeningUserId != uid) return;
            _sharedGardenLoading = false;
            _sharedGardenError = null;
            _setSharedGarden(garden);
          },
          onError: (Object error) {
            debugPrint('MindraState: watchUserGarden error: $error');
            if (_disposed || _listeningUserId != uid) return;
            _sharedGardenLoading = false;
            _sharedGardenError =
                'Không tải được khu vườn. Hãy kiểm tra kết nối và thử lại.';
            _setSharedGarden(null);
          },
        );
  }

  void retrySharedGarden() {
    _sharedGardenError = null;
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      _listeningUserId = null;
      _watchUserGarden(uid);
      notifyListeners();
      return;
    }

    _authRepository
        .signInAnonymously()
        .then((cred) {
          if (_disposed) return;
          final newUid = cred?.user.id;
          if (newUid != null) {
            _listeningUserId = null;
            _watchUserGarden(newUid);
          } else {
            _sharedGardenLoading = false;
            _sharedGardenError =
                'Không tải được khu vườn. Hãy kiểm tra kết nối và thử lại.';
          }
          notifyListeners();
        })
        .catchError((Object error) {
          if (_disposed) return;
          _sharedGardenLoading = false;
          _sharedGardenError =
              'Không tải được khu vườn. Hãy kiểm tra kết nối và thử lại.';
          notifyListeners();
        });
    notifyListeners();
  }

  void loadDemoSharedGarden() {
    _isDemoSharedGarden = true;
    _sharedGardenError = null;
    _sharedGardenLoading = false;
    final myId = _authRepository.currentUserId ?? 'current_user';
    final myName = userName.isNotEmpty ? userName : 'Bạn';
    _sharedGarden = SharedGarden(
      id: 'demo-shared-garden',
      code: 'MINDRA-DEMO',
      name: 'Vườn sẻ chia mẫu',
      members: ['demo_user_1', myId],
      memberNames: {
        'demo_user_1': 'An Nhiên',
        'demo_user_2': 'Minh Khang',
        myId: myName,
      },
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    );
    _sharedMoments.clear();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _sharedMoments.addAll([
      SharedMoment(
        id: 'shared-moment-demo-1',
        gardenId: 'demo-shared-garden',
        authorId: 'demo_user_1',
        authorName: 'An Nhiên',
        emotionKey: 'calm',
        intensity: 4,
        caption: 'Ngắm bình minh sáng sớm và nhâm nhi ly trà ấm.',
        slotIndex: 2,
        bedIndex: 0,
        monthKey: monthKey,
        plantedAt: now.subtract(const Duration(hours: 3)),
        waterCount: 4,
        sunCount: 5,
      ),
      SharedMoment(
        id: 'shared-moment-demo-2',
        gardenId: 'demo-shared-garden',
        authorId: myId,
        authorName: myName,
        emotionKey: 'happy',
        intensity: 5,
        caption: 'Hoàn thành bài thuyết trình đồ án liên ngành suôn sẻ!',
        slotIndex: 7,
        bedIndex: 0,
        monthKey: monthKey,
        plantedAt: now.subtract(const Duration(hours: 8)),
        waterCount: 6,
        sunCount: 8,
      ),
      SharedMoment(
        id: 'shared-moment-demo-3',
        gardenId: 'demo-shared-garden',
        authorId: myId,
        authorName: myName,
        emotionKey: 'grateful',
        intensity: 4,
        caption: 'Biết ơn vì luôn có những người bạn đồng hành lắng nghe.',
        slotIndex: 12,
        bedIndex: 0,
        monthKey: monthKey,
        plantedAt: now.subtract(const Duration(days: 1)),
        waterCount: 3,
        sunCount: 4,
      ),
    ]);
    notifyListeners();
  }

  void _clearSharedSession() {
    _listeningUserId = null;
    ++_sharedRevision;
    _sharedGardenSubscription?.cancel();
    _sharedMomentsSubscription?.cancel();
    _sharedGarden = null;
    _sharedMoments.clear();
    _sharedGardenLoading = false;
    _sharedGardenError = null;
    _isSharedGardenMode = false;
  }

  String _requireUserId() {
    if (_isDemoSharedGarden) throw StateError('Không thể ghi vào vườn mẫu.');
    final uid = _authRepository.currentUserId;
    if (uid == null) throw StateError('Hãy đăng nhập để sử dụng vườn chung.');
    return uid;
  }

  Future<SharedGarden> createSharedGarden({
    String? gardenName,
    String? displayName,
  }) async {
    final uid = _requireUserId();
    final garden = await _sharedGardenRepository.createGarden(
      userId: uid,
      userName: displayName ?? sharedDisplayNameSuggestion,
      gardenName: gardenName,
    );
    if (!_disposed && _authRepository.currentUserId == uid) {
      _setSharedGarden(garden);
    }
    return garden;
  }

  Future<bool> joinSharedGarden(String code, {String? displayName}) async {
    final uid = _requireUserId();
    final garden = await _sharedGardenRepository.joinGardenByCode(
      code: code,
      userId: uid,
      userName: displayName ?? sharedDisplayNameSuggestion,
    );
    if (garden == null) return false;
    if (!_disposed && _authRepository.currentUserId == uid) {
      _setSharedGarden(garden);
    }
    return true;
  }

  Future<void> plantInSharedGarden(String entryId) async {
    final uid = _requireUserId();
    final gardenId = _sharedGarden?.id;
    if (gardenId == null) throw StateError('Hãy chọn một khu vườn.');
    if (entryById(entryId) == null) {
      throw StateError('Ghi chép không còn tồn tại.');
    }
    final moment = await _sharedGardenRepository.plantEntry(gardenId, entryId);
    if (_disposed ||
        _authRepository.currentUserId != uid ||
        _sharedGarden?.id != gardenId) {
      return;
    }
    _sharedMoments.removeWhere((m) => m.id == moment.id);
    _sharedMoments.add(moment);
    notifyListeners();
  }

  Future<void> sendCareReaction({
    required String momentId,
    required bool isWater,
  }) async {
    final uid = _requireUserId();
    final gardenId = _sharedGarden?.id;
    if (gardenId == null) throw StateError('Hãy chọn một khu vườn.');
    final moment = await _sharedGardenRepository.interactMoment(
      gardenId: gardenId,
      momentId: momentId,
      isWater: isWater,
      interactorName: _userName,
    );
    if (_disposed ||
        _authRepository.currentUserId != uid ||
        _sharedGarden?.id != gardenId) {
      return;
    }
    final index = _sharedMoments.indexWhere((m) => m.id == moment.id);
    if (index != -1) _sharedMoments[index] = moment;
    notifyListeners();
  }

  Future<String> refreshSharedInvite() async {
    _requireUserId();
    final gardenId = _sharedGarden?.id;
    if (gardenId == null) throw StateError('Hãy chọn một khu vườn.');
    return _sharedGardenRepository.refreshInvite(gardenId);
  }

  Future<void> leaveSharedGarden({bool removeMyFlowers = false}) async {
    if (_isDemoSharedGarden) {
      _isDemoSharedGarden = false;
      _setSharedGarden(null);
      return;
    }
    final uid = _requireUserId();
    final gardenId = _sharedGarden?.id;
    if (gardenId == null) return;
    if (removeMyFlowers) {
      await _sharedGardenRepository.removeMyMoments(gardenId);
    }
    await _sharedGardenRepository.leaveGarden(gardenId);
    if (!_disposed &&
        _authRepository.currentUserId == uid &&
        _sharedGarden?.id == gardenId) {
      _setSharedGarden(null);
    }
  }

  /// Practice is a separate event: missing before/after answers stay unknown.
  String recordPractice({
    String? id,
    required String exerciseId,
    String note = '',
    String? sourceEntryId,
    String? beforeEmotionKey,
    int? beforeIntensity,
    String? afterEmotionKey,
    int? afterIntensity,
    int? usefulnessRating,
    int? easeRating,
    String? repeatPreference,
  }) {
    final recordId = id ?? 'practice-${DateTime.now().microsecondsSinceEpoch}';
    final previous = _practiceRecords
        .where((r) => r.id == recordId)
        .firstOrNull;
    final record = PracticeRecord(
      id: recordId,
      exerciseId: exerciseId,
      timestamp: previous?.timestamp ?? DateTime.now(),
      sourceEntryId: sourceEntryId,
      note: note.trim(),
      beforeEmotionKey: beforeEmotionKey,
      beforeIntensity: beforeIntensity,
      afterEmotionKey: afterEmotionKey,
      afterIntensity: afterIntensity,
      usefulnessRating: usefulnessRating,
      easeRating: easeRating,
      repeatPreference: repeatPreference,
    );
    _practiceRecords.removeWhere((r) => r.id == recordId);
    _practiceRecords.insert(0, record);
    _pendingPracticeIds.add(recordId);
    final saved = _persistJournal();
    unawaited(saved.then((_) => _uploadPractice(record)));
    notifyListeners();
    return recordId;
  }

  bool completeExercise({
    required String exerciseId,
    String note = '',
    String? afterEmotionKey,
    int? afterIntensity,
    int? usefulnessRating,
    int? easeRating,
    String? repeatPreference,
  }) {
    final source = todayEntry;
    recordPractice(
      exerciseId: exerciseId,
      note: note,
      sourceEntryId: source?.id,
      beforeEmotionKey: null,
      beforeIntensity: null,
      afterEmotionKey: afterEmotionKey,
      afterIntensity: afterIntensity,
      usefulnessRating: usefulnessRating,
      easeRating: easeRating,
      repeatPreference: repeatPreference,
    );
    return true;
  }

  Future<void> _uploadPractice(PracticeRecord record) {
    final uid = currentUserId;
    final revision = _sessionRevision;
    if (uid == null) return Future.value();
    _practiceQueue = _practiceQueue.then((_) async {
      if (_disposed || currentUserId != uid || revision != _sessionRevision) {
        return;
      }
      try {
        final sourceId = record.sourceEntryId;
        final source = sourceId == null ? null : entryById(sourceId);
        if (source != null) {
          // Server chỉ nhận buổi tập khi check-in gốc đã có trên server.
          if (entrySyncStatus(source.id) != EntrySyncStatus.synced &&
              !_pendingEntryWrites.containsKey(source.id)) {
            _queueEntryWrite(source);
          }
          final writes = _pendingEntryWrites[source.id];
          if (writes != null) await Future.wait(List.of(writes));
          if (entrySyncStatus(source.id) != EntrySyncStatus.synced) {
            throw StateError('source entry not synced');
          }
        }
        await _practiceRepository.save(record);
        if (_disposed || currentUserId != uid || revision != _sessionRevision) {
          return;
        }
        // A later edit still needs to be uploaded.
        if (identical(
          _practiceRecords.where((r) => r.id == record.id).firstOrNull,
          record,
        )) {
          _pendingPracticeIds.remove(record.id);
        }
        await _persistJournal();
      } catch (_) {
        if (!_disposed &&
            currentUserId == uid &&
            revision == _sessionRevision) {
          _personalDataError = 'Buổi thực hành đã lưu trên máy, chưa đồng bộ. Bạn có thể thử cập nhật lại.';
          notifyListeners();
        }
      }
    });
    return _practiceQueue;
  }

  Future<void> _refreshPractice(String uid) async {
    final revision = _sessionRevision;
    for (final record in List<PracticeRecord>.of(_practiceRecords)) {
      if (_pendingPracticeIds.contains(record.id)) {
        await _uploadPractice(record);
      }
    }
    try {
      final records = await _practiceRepository.fetch();
      if (_disposed || currentUserId != uid || revision != _sessionRevision)
        return;
      final pending = _practiceRecords
          .where((r) => _pendingPracticeIds.contains(r.id))
          .toList();
      _practiceRecords
        ..clear()
        ..addAll(records.where((r) => !pending.any((p) => p.id == r.id)))
        ..addAll(pending)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _persistJournal();
      notifyListeners();
    } catch (_) {
      /* The local history remains available. */
    }
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
  bool _aiConsent = false;
  int _aiConsentChanges = 0;
  Future<void> _consentQueue = Future.value();
  bool get aiConsent => _aiConsent;

  bool _lowStimulationMode = false;
  bool get lowStimulationMode => _lowStimulationMode;

  bool _gardenVisible = true;
  bool get gardenVisible => _gardenVisible;

  bool _appLockEnabled = false;
  bool get appLockEnabled => _appLockEnabled;
  bool _appUnlocked = false;
  bool get appUnlocked => _appUnlocked;
  void lockApplication() {
    if (!_appLockEnabled || _disposed) return;
    _appUnlocked = false;
    notifyListeners();
  }

  Future<bool> unlockApplication() async {
    final revision = _sessionRevision;
    final accepted = await _deviceAuth.authenticate();
    if (!accepted || _disposed || revision != _sessionRevision) return false;
    _appUnlocked = true;
    notifyListeners();
    return true;
  }

  /// Lối thoát khi thiết bị không xác thực được nữa: tắt khóa và đăng xuất.
  /// Đăng nhập lại cần mật khẩu, nên không ai đọc được dữ liệu nhờ nút này.
  Future<void> signOutFromLock() async {
    _appLockEnabled = false;
    await _savePreferences();
    await logout();
  }

  bool _reminderEnabled = false;
  bool get reminderEnabled => _reminderEnabled;

  String _reminderTime = '21:00';
  String get reminderTime => _reminderTime;

  final List<String> _userGoals = [
    'Hiểu cảm xúc của tôi',
    'Giảm căng thẳng hằng ngày',
  ];
  List<String> get userGoals => List.unmodifiable(_userGoals);

  Map<String, String>? _weeklyReview;
  final Map<String, Map<String, String>> _weeklyReviewHistory = {};
  List<Map<String, String>> get weeklyReviewHistory =>
      _weeklyReviewHistory.values.toList()
        ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
  Map<String, String>? get weeklyReview {
    final review = _weeklyReview;
    final date = DateTime.tryParse(review?['date'] ?? '');
    if (date == null) return null;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return !date.isBefore(start) &&
            date.isBefore(start.add(const Duration(days: 7)))
        ? Map.unmodifiable(review!)
        : null;
  }

  String _aiConsentKey(String uid) => 'moodi.aiConsent.$uid.v2';
  static const _prefsStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  void setAiConsent(bool val) {
    _aiConsent = val;
    _aiConsentChanges++;
    notifyListeners();
    final uid = currentUserId;
    if (uid == null) return;
    _consentQueue = _consentQueue.then((_) => _prefsStorage.write(key: _aiConsentKey(uid), value: val.toString())).catchError((Object e) => debugPrint('aiConsent save failed: $e'));

  }

  /// Đọc lựa chọn gửi nhật ký cho AI đã lưu (gọi khi mở app).
  Future<void> loadAiConsent() async {
    final changes = _aiConsentChanges;
    final uid = currentUserId;
    final revision = _sessionRevision;
    if (uid == null) return;
    try {
      var raw = await _prefsStorage.read(key: _aiConsentKey(uid));
      if (raw == null &&
          await _prefsStorage.read(key: 'moodi.aiConsent.v1') == 'true') {
        // Bản cũ lưu lựa chọn chung cho máy: giữ lại lựa chọn bật AI rõ ràng.
        raw = 'true';
        await _prefsStorage.write(key: _aiConsentKey(uid), value: raw);
      }
      if (_disposed || currentUserId != uid || revision != _sessionRevision || changes != _aiConsentChanges) return;
      _aiConsent = raw == 'true';
      notifyListeners();
    } catch (e) {
      debugPrint('aiConsent load failed: $e');
    }
  }

  void setLowStimulationMode(bool val) {
    _lowStimulationMode = val;
    notifyListeners();
    _savePreferences();
  }

  void setGardenVisible(bool val) {
    _gardenVisible = val;
    notifyListeners();
    _savePreferences();
  }

  // Cài đặt trên máy (không theo tài khoản): onboarding, mục tiêu, giảm kích
  // thích, hiển thị vườn. Lưu trong Keychain/Keystore như token phiên.
  static const _preferencesKey = 'moodi.preferences.v1';
  bool _loadingPreferences = false;

  /// Đang đọc cài đặt hoặc khôi phục phiên: chưa biết nên mở màn nào.
  bool get startingUp => _restoringSession || _loadingPreferences;

  Future<void> loadLocalPreferences() async {
    _loadingPreferences = true;
    try {
      await loadAiConsent();
      final raw = await _prefsStorage.read(key: _preferencesKey);
      if (raw == null || _disposed) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['onboardingCompleted'] == true) _onboardingCompleted = true;
      _lowStimulationMode =
          data['lowStimulation'] as bool? ?? _lowStimulationMode;
      _gardenVisible = data['gardenVisible'] as bool? ?? _gardenVisible;
      _appLockEnabled = data['appLock'] as bool? ?? false;
      _appUnlocked = false;
      final goals = (data['goals'] as List?)?.whereType<String>().toList();
      if (goals != null && goals.isNotEmpty) {
        _userGoals
          ..clear()
          ..addAll(goals);
      }
    } catch (e) {
      debugPrint('MindraState: load preferences failed ($e)');
    } finally {
      _loadingPreferences = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _preferencesQueue = Future.value();
  Future<bool> _savePreferences() {
    final snapshot = jsonEncode({
      'onboardingCompleted': _onboardingCompleted,
      'lowStimulation': _lowStimulationMode,
      'gardenVisible': _gardenVisible,
      'appLock': _appLockEnabled,
      'goals': _userGoals,
    });
    final write = _preferencesQueue.then(
      (_) => _prefsStorage.write(key: _preferencesKey, value: snapshot),
    );
    _preferencesQueue = write.catchError(
      (Object e) => debugPrint('preferences save failed: $e'),
    );
    return write.then((_) => true, onError: (Object _) => false);
  }

  // Bước nhỏ và bài nhìn lại tuần: lưu trên máy, tách theo từng tài khoản.
  String _userContentKey(String uid) => 'moodi.user.$uid.v1';

  Future<void> _loadUserContent(String uid) async {
    final revision = _sessionRevision;
    try {
      final raw = await _prefsStorage.read(key: _userContentKey(uid));
      if (raw == null ||
          _disposed ||
          currentUserId != uid ||
          revision != _sessionRevision) {
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final goals = (data['microGoals'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MicroGoal.fromJson)
          .toList();
      final history = data['weeklyReviewHistory'];
      if (history is Map) {
        for (final e in history.entries) {
          if (e.value is Map) {
            _weeklyReviewHistory[e.key.toString()] = (e.value as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
        }
      }
      final review = data['weeklyReview'];
      final savedReflections = data['reflections'];
      if (savedReflections is Map) {
        for (final e in savedReflections.entries) {
          final entry = entryById(e.key.toString());
          final inputs = data['reflectionInputs'] as Map?;
          if (entry != null &&
              inputs?[entry.id] == _reflectionInput(entry) &&
              e.value is Map) {
            _aiReflections.putIfAbsent(
              e.key.toString(),
              () => AIReflection.fromJson(Map<String, dynamic>.from(e.value)),
            );
          }
        }
      }
      _unsentFeedback.addAll(
        (data['unsentFeedback'] as List? ?? []).whereType<String>(),
      );
      _microGoals
        ..clear()
        ..addAll(goals);
      _weeklyReview = review is Map
          ? review.map((k, v) => MapEntry(k.toString(), v.toString()))
          : null;
      if (_weeklyReview != null) {
        final date = DateTime.tryParse(_weeklyReview!['date'] ?? '');
        if (date != null) {
          final start = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
          _weeklyReviewHistory.putIfAbsent(start.toIso8601String(), () => Map.of(_weeklyReview!));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('MindraState: load user content failed ($e)');
    }
  }

  void _saveUserContent() {
    final uid = currentUserId;
    final revision = _sessionRevision;
    if (uid == null) return;
    final snapshot = jsonEncode({
      'microGoals': [
        for (final g in _microGoals) {...g.toJson(), 'id': g.id},
      ],
      'weeklyReview': _weeklyReview,
      'weeklyReviewHistory': _weeklyReviewHistory,
      'reflectionInputs': {for (final e in _entries) e.id: _reflectionInput(e)},
      'reflections': {
        for (final e in _aiReflections.entries) e.key: e.value.toJson(),
      },
      'unsentFeedback': _unsentFeedback.toList(),
    });
    _userContentQueue = _userContentQueue
        .then(
          (_) =>
              _prefsStorage.write(key: _userContentKey(uid), value: snapshot),
        )
        .then((_) {
          if (!_disposed && currentUserId == uid && revision == _sessionRevision) {
            _userContentWriteFailed = false;
          }
        })
        .catchError((Object e) {
          if (!_disposed && currentUserId == uid && revision == _sessionRevision) {
            _userContentWriteFailed = true;
            notifyListeners();
          }
        });
  }

  Future<bool> setAppLockEnabled(bool val) async {
    if (val == _appLockEnabled) return true;
    final revision = _sessionRevision;
    if (!await _deviceAuth.authenticate() ||
        _disposed ||
        revision != _sessionRevision) {
      return false;
    }
    final previous = _appLockEnabled;
    _appLockEnabled = val;
    _appUnlocked = true;
    if (!await _savePreferences()) {
      _appLockEnabled = previous;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Đọc lại nhắc nhở đang lên lịch trong hệ điều hành (gọi khi mở app).
  Future<void> loadReminder() async {
    final time = await _reminderService.load();
    _reminderEnabled = time != null;
    if (time != null) _reminderTime = time;
    notifyListeners();
  }

  /// Trả false khi người dùng không cấp quyền thông báo.
  Future<bool> setReminderEnabled(bool val) async {
    if (val) {
      try {
        if (!await _reminderService.schedule(_reminderTime)) return false;
      } catch (e) {
        debugPrint('MindraState: schedule reminder error: $e');
        return false;
      }
    } else {
      try {
        await _reminderService.cancel();
      } catch (_) {
        return false;
      }
    }
    _reminderEnabled = val;
    notifyListeners();
    return true;
  }

  Future<bool> setReminderTime(String val) async {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(val)) return false;
    if (_reminderEnabled) {
      try {
        if (!await _reminderService.schedule(val)) return false;
      } catch (_) {
        return false;
      }
    }
    _reminderTime = val;
    notifyListeners();
    return true;
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
    _savePreferences();
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
    final day = DateTime.now();
    final start = DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: day.weekday - 1));
    _weeklyReviewHistory[start.toIso8601String()] = Map.of(_weeklyReview!);
    notifyListeners();
    _saveUserContent();
  }

  Map<String, dynamic> exportPersonalData() => {
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'scope': 'personal-journal-garden-practice-and-local-preferences',
    'entries': [
      for (final e in _entries)
        {...e.toJson(), 'id': e.id, 'syncStatus': entrySyncStatus(e.id).name},
    ],
    'reflections': {
      for (final e in _aiReflections.entries) e.key: e.value.toJson(),
    },
    'gardenMoments': [
      for (final m in _gardenMoments) {...m.toJson(), 'id': m.id},
    ],
    'practiceRecords': [for (final r in _practiceRecords) r.toJson()],
    'microGoals': [
      for (final g in _microGoals) {...g.toJson(), 'id': g.id},
    ],
    'weeklyReview': _weeklyReview,
    'weeklyReviewHistory': _weeklyReviewHistory,
    'preferences': {
      'goals': userGoals,
      'aiConsent': aiConsent,
      'lowStimulation': lowStimulationMode,
      'gardenPreview': gardenVisible,
    },
  };

  void clearAllData() {
    _entrySync.clear();
    _entryWriteVersions.clear();
    _awaitingRemoteEntryIds.clear();
    _remoteMisses.clear();
    _entries.clear();
    _gardenMoments.clear();
    for (final id in {..._aiReflections.keys, ..._reflectionRequests.keys}) {
      _reflectionVersions[id] = (_reflectionVersions[id] ?? 0) + 1;
    }
    _aiReflections.clear();
    _unsentFeedback.clear();
    _reflectionRequests.clear();
    _weeklyReview = null;
    _weeklyReviewHistory.clear();
    _microGoals.clear();
    _practiceRecords.clear();
    _pendingPracticeIds.clear();
    _durableEntryIds.clear();
    unawaited(_persistJournal());
    notifyListeners();
    _saveUserContent();
  }

  // Onboarding (S01–S04)
  bool _onboardingCompleted = false;
  bool get onboardingCompleted => _onboardingCompleted;

  void completeOnboarding() {
    _onboardingCompleted = true;
    notifyListeners();
    _savePreferences();
  }

  void resetOnboarding() {
    _onboardingCompleted = false;
    notifyListeners();
    _savePreferences();
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
    _saveUserContent();
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
      _saveUserContent();
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

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw StateError('Tên cần từ 1 đến 100 ký tự.');
    }
    final id = currentUserId;
    if (id == null) throw StateError('Hãy đăng nhập để sửa hồ sơ.');
    final updated = await _userRepository.updateProfile(
      userId: id,
      displayName: trimmed,
    );
    if (updated == null) throw StateError('Chưa lưu được tên.');
    _userName = updated.displayName.trim().isEmpty
        ? trimmed
        : updated.displayName.trim();
    notifyListeners();
  }

  void _resetSessionUi() {
    _hasChosenEmotion = false;
    _selectedEmotionKey = 'happy';
    _currentIntensity = 3;
    _currentTab = 0;
    _personalSpaceSection = 0;
    _gardenFocusMonthKey = null;
    _journalFocusDate = null;
    _appUnlocked = false;
    _aiConsent = false;
    _loadingPersonalData = false;
    _personalDataError = null;
    _lastPersonalSync = null;
    _cacheWriteFailed = false;
    _durableEntryIds.clear();
    _weeklyReviewHistory.clear();
    _practiceRecords.clear();
    _pendingPracticeIds.clear();
  }

  Future<void> logout() async {
    await _persistJournal();
    await flushLocalData();
    await authRepository.signOut();
    _resetSessionUi();
    _clearSharedSession();
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();
    _sharedGardenSubscription?.cancel();
    _sharedMomentsSubscription?.cancel();
    _sharedGarden = null;
    _sharedMoments.clear();
    _aiReflections.clear();
    _unsentFeedback.clear();
    _reflectionRequests.clear();
    _weeklyReview = null;
    _sessionRevision++;
    _isAuthenticated = false;
    _onboardingCompleted = true;
    _savePreferences();
    _demoScenario = DemoScenario.firstLaunch;
    _entrySync.clear();
    _entryWriteVersions.clear();
    _awaitingRemoteEntryIds.clear();
    _remoteMisses.clear();
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
    _unsentFeedback.clear();
    _reflectionRequests.clear();
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

  Future<AIReflection> fetchOrGenerateAIReflection(JournalEntry entry) {
    final cached = reflectionForEntry(entry.id);
    if (cached != null) return Future.value(cached);
    if (!aiConsent)
      return Future.error(StateError('Bạn chưa bật gợi ý phản tư.'));
    return _reflectionRequests[entry.id] ??= _generateReflection(entry);
  }

  Future<AIReflection> _generateReflection(JournalEntry entry) async {
    final revision = _sessionRevision;
    final contentVersion = _reflectionVersions[entry.id] ?? 0;
    bool stillCurrent() =>
        !_disposed &&
        revision == _sessionRevision &&
        contentVersion == (_reflectionVersions[entry.id] ?? 0);
    try {
      final pending = _pendingEntryWrites[entry.id];
      if (pending != null) await Future.wait(List.of(pending));
      if (!stillCurrent()) throw StateError('Ghi chép hoặc phiên đã thay đổi.');
      if (!aiConsent) throw StateError('Gợi ý phản tư đã được tắt.');
      final generated = await _reflectionRepository.generateReflection(
        emotionKey: entry.emotionKey,
        intensity: entry.intensity,
        situation: entry.situation,
        thought: entry.thought,
        entryId: entry.id,
      );
      if (!stillCurrent()) {
        throw StateError('Nhật ký hoặc phiên đăng nhập đã thay đổi.');
      }
      final edited = _aiReflections[entry.id];
      if (!generated.safetyFlag && edited?.userFeedback != null) {
        final merged = edited!.copyWith(id: generated.id);
        updateAIReflection(entry.id, merged);
        return merged;
      }
      cacheAIReflection(entry.id, generated);
      _saveUserContent();
      notifyListeners();
      return generated;
    } finally {
      if (stillCurrent()) _reflectionRequests.remove(entry.id);
    }
  }

  String _reflectionInput(JournalEntry e) => sha256
      .convert(
        utf8.encode(
          jsonEncode([e.emotionKey, e.intensity, e.situation, e.thought]),
        ),
      )
      .toString();

  Future<void> _loadSavedReflections(String userId) async {
    final revision = _sessionRevision;
    final versions = Map.of(_reflectionVersions);
    final saved = await _reflectionRepository.getReflectionsByEntry();
    if (_disposed ||
        currentUserId != userId ||
        revision != _sessionRevision ||
        saved.isEmpty) {
      return;
    }
    // Không ghi đè bản đang có trong phiên (có thể người dùng vừa sửa).
    saved.forEach((entryId, r) {
      if (entryById(entryId) != null &&
          entrySyncStatus(entryId) == EntrySyncStatus.synced &&
          versions[entryId] == _reflectionVersions[entryId]) {
        _aiReflections.putIfAbsent(entryId, () => r);
      }
    });
    notifyListeners();
  }

  void _startApiListeners(String userId) {
    unawaited(_loadPersonalData(userId));
  }

  Future<void> _loadPersonalData(String userId) async {
    final revision = _sessionRevision;
    _loadingPersonalData = true;
    final restored = _loadJournalCache(userId);
    _restoringJournalCache = restored;
    await restored;
    if (identical(_restoringJournalCache, restored)) {
      _restoringJournalCache = null;
    }
    if (_disposed || currentUserId != userId || revision != _sessionRevision) {
      return;
    }
    await loadAiConsent();
    if (_disposed || currentUserId != userId || revision != _sessionRevision) return;
    await _loadUserContent(userId);
    if (_disposed || currentUserId != userId || revision != _sessionRevision) {
      return;
    }
    _resendFeedback();
    unawaited(_loadSavedReflections(userId));
    unawaited(_refreshPractice(userId));
    _sharedGardenRepository.setCurrentUserId(userId);
    _watchUserGarden(userId);
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();

    _entriesSubscription = _journalRepository
        .watchEntries(userId: userId)
        .listen(
          (remoteEntries) {
            if (_disposed ||
                currentUserId != userId ||
                revision != _sessionRevision)
              return;
            _mergeRemoteEntries(remoteEntries);
            _loadingPersonalData = false;
            _personalDataError = null;
            _lastPersonalSync = DateTime.now();
            unawaited(_persistJournal());
            retryEntrySync();
            notifyListeners();
          },
          onError: (e) {
            if (_disposed ||
                currentUserId != userId ||
                revision != _sessionRevision)
              return;
            _loadingPersonalData = false;
            _personalDataError = 'Chưa tải được nhật ký mới nhất. Dữ liệu đã có trên máy vẫn được giữ.';
            notifyListeners();
          },
        );

    _gardenSubscription = _gardenRepository
        .watchMoments(userId: userId)
        .listen(
          (remoteMoments) {
            if (_disposed ||
                currentUserId != userId ||
                revision != _sessionRevision)
              return;
            _gardenMoments
              ..clear()
              ..addAll(remoteMoments);
            unawaited(_persistJournal());
            notifyListeners();
          },
          onError: (e) {
            if (_disposed ||
                currentUserId != userId ||
                revision != _sessionRevision)
              return;
            _personalDataError =
                'Chưa cập nhật được khu vườn. Hãy thử lại khi có kết nối.';
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _clearSharedSession();
    _sharedGardenRepository.dispose();
    _authSubscription?.cancel();
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();
    _sharedGardenSubscription?.cancel();
    _sharedMomentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> syncFromApi() async {
    final revision = _sessionRevision;
    final uid = _authRepository.currentUserId;
    if (uid == null) return;
    try {
      final remoteEntries = await _journalRepository.fetchEntries(userId: uid);
      if (_disposed || currentUserId != uid || revision != _sessionRevision)
        return;
      _mergeRemoteEntries(remoteEntries);
      final remoteMoments = await _gardenRepository.fetchMoments(userId: uid);
      if (_disposed || revision != _sessionRevision) return;
      _gardenMoments
        ..clear()
        ..addAll(remoteMoments);
      _loadingPersonalData = false;
      _personalDataError = null;
      _lastPersonalSync = DateTime.now();
      await _persistJournal();
      unawaited(_refreshPractice(uid));
      _resendFeedback();
      retryEntrySync();
      notifyListeners();
    } catch (e) {
      if (_disposed || currentUserId != uid || revision != _sessionRevision) {
        return;
      }
      _loadingPersonalData = false;
      _personalDataError =
          'Chưa kết nối được. Dữ liệu đã lưu trên máy vẫn được giữ.';
      notifyListeners();
    }
  }
}

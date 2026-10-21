import 'dart:async';

import '../repositories/post_repository.dart';

import 'package:flutter/foundation.dart';

import '../core/garden_layout.dart';
import '../models/ai_reflection.dart';
import '../models/badge_item.dart';
import '../models/emotion.dart';
import '../models/garden_moment.dart';
import '../models/journal_entry.dart';
import '../models/micro_goal.dart';
import '../models/shared_garden.dart';
import '../repositories/auth_repository.dart';
import '../repositories/garden_repository.dart';
import '../repositories/journal_repository.dart';
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
    List<JournalEntry>? initialEntries,
    List<MicroGoal>? initialMicroGoals,
    bool? isAuthenticated,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _journalRepository = journalRepository ?? JournalRepository(),
       _gardenRepository = gardenRepository ?? GardenRepository(),
       _reflectionRepository = reflectionRepository ?? ReflectionRepository(),
        _sharedGardenRepository =
            sharedGardenRepository ?? SharedGardenRepository(),
        _userRepository = userRepository ?? UserRepository() {
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
        _entriesSubscription?.cancel();
        _gardenSubscription?.cancel();
        _clearSharedSession();
        _entries.clear();
        _gardenMoments.clear();
        _aiReflections.clear();
        _weeklyReview = null;
        _posts.clear();
        _microGoals.clear();
        _entrySync.clear();
        _entryWriteVersions.clear();
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

  void openJournal() {
    _personalSpaceSection = 0;
    setTab(1);
    notifyListeners();
  }

  void openGarden() {
    _personalSpaceSection = 1;
    setTab(1);
    notifyListeners();
  }

  final _postRepository = PostRepository();
  List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);
  Future<void> fetchPosts() async {
    final revision = _sessionRevision;
    final page = await _postRepository.getPosts();
    if (_disposed || revision != _sessionRevision) return;
    if (page != null) {
      _posts = page.data;
      notifyListeners();
    }
  }

  Future<void> createPost(String content, List<String>? images) async {
    final result = await _postRepository.createPost(
      content: content,
      imageUrls: images,
    );
    if (result == null) throw StateError('Không thể đăng bài.');
    await fetchPosts();
  }

  Future<void> likePost(String id) async {
    if (!await _postRepository.likePost(id)) {
      throw StateError('Không thể đồng cảm.');
    }
    await fetchPosts();
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
      if (restored && !_disposed) _onboardingCompleted = true;
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

  /// Hiện nút Google/Apple chỉ khi cả app lẫn server đã cấu hình.
  Future<void> loadSocialProviders() async {
    final social = _authRepository.socialSignIn;
    final server = await _authRepository.socialProviders();
    final apple = server.apple && await social.appleAvailable();
    if (_disposed) return;
    _socialProviders = (
      google: server.google && social.googleConfigured,
      apple: apple,
    );
    notifyListeners();
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
    await Future.wait(List.of(_pendingWrites));
    final uid = _requireUserId();
    final revision = _sessionRevision;
    if (_sharedGarden != null) {
      await _sharedGardenRepository.removeMyMoments(_sharedGarden!.id);
    }
    await _journalRepository.deleteAllEntries(userId: uid);
    await _gardenRepository.deleteAllMoments(userId: uid);
    if (!_disposed && revision == _sessionRevision) clearAllData();
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
    _hasChosenEmotion = true;
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

  final Map<String, EntrySyncStatus> _entrySync = {};
  final Map<String, int> _entryWriteVersions = {};
  int _entryWriteSequence = 0;
  final Set<Future<void>> _pendingWrites = {};
  EntrySyncStatus entrySyncStatus(String id) =>
      _entrySync[id] ?? EntrySyncStatus.synced;
  int get pendingEntryCount =>
      _entrySync.values.where((s) => s == EntrySyncStatus.pending).length;
  int get failedEntryCount =>
      _entrySync.values.where((s) => s == EntrySyncStatus.failed).length;
  int get sessionEntryCount =>
      _entrySync.values.where((s) => s == EntrySyncStatus.sessionOnly).length;

  String entrySaveMessage(String id) => switch (entrySyncStatus(id)) {
    EntrySyncStatus.pending => 'Đang đồng bộ ghi chép…',
    EntrySyncStatus.synced => 'Ghi chép đã được đồng bộ.',
    EntrySyncStatus.failed => 'Chưa đồng bộ được. Mở Nhật ký để thử lại.',
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
    _entries[index] = entry;
    _queueEntryWrite(entry);
  }

  void _queueEntryWrite(JournalEntry entry) {
    final uid = currentUserId;
    final version = ++_entryWriteSequence;
    _entryWriteVersions[entry.id] = version;
    _entrySync[entry.id] = uid == null
        ? EntrySyncStatus.sessionOnly
        : EntrySyncStatus.pending;
    notifyListeners();
    if (uid == null) return;
    final write = _writeEntry(entry, uid, version);
    _pendingWrites.add(write);
    unawaited(write.whenComplete(() => _pendingWrites.remove(write)));
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
    if (uid != null) {
      if (isSharedPlanted(id)) await removeSharedMoment('${uid}_$id');
      await _journalRepository.deleteEntry(id, userId: uid);
    }
    if (_disposed || _authRepository.currentUserId != uid) return;
    _entrySync.remove(id);
    _entryWriteVersions.remove(id);
    _entries.removeWhere((e) => e.id == id);
    _gardenMoments.removeWhere((moment) => moment.entryId == id);
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
    _entrySync.clear();
    _entryWriteVersions.clear();
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

  Future<void> logout() async {
    await authRepository.signOut();
    _clearSharedSession();
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();
    _sharedGardenSubscription?.cancel();
    _sharedMomentsSubscription?.cancel();
    _sharedGarden = null;
    _sharedMoments.clear();
    _aiReflections.clear();
    _weeklyReview = null;
    _sessionRevision++;
    _isAuthenticated = false;
    _onboardingCompleted = true;
    _demoScenario = DemoScenario.firstLaunch;
    _entrySync.clear();
    _entryWriteVersions.clear();
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
    final revision = _sessionRevision;
    final generated = await _reflectionRepository.generateReflection(
      emotionKey: entry.emotionKey,
      intensity: entry.intensity,
      situation: entry.situation,
      thought: entry.thought,
      entryId: entry.id,
    );
    if (_disposed || revision != _sessionRevision) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    cacheAIReflection(entry.id, generated);
    notifyListeners();
    return generated;
  }

  void _startApiListeners(String userId) {
    _sharedGardenRepository.setCurrentUserId(userId);
    _watchUserGarden(userId);
    _entriesSubscription?.cancel();
    _gardenSubscription?.cancel();

    _entriesSubscription = _journalRepository
        .watchEntries(userId: userId)
        .listen(
          (remoteEntries) {
            if (_disposed || currentUserId != userId) return;
            final unsynced = _entries
                .where((e) => entrySyncStatus(e.id) != EntrySyncStatus.synced)
                .toList();
            final localIds = unsynced.map((e) => e.id).toSet();
            _entries
              ..clear()
              ..addAll(remoteEntries.where((e) => !localIds.contains(e.id)))
              ..addAll(unsynced)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            final today = _entryForDay(DateTime.now());
            if (today != null) _selectedEmotionKey = today.emotionKey;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('MindraState: Error watching entries ($e)');
          },
        );

    _gardenSubscription = _gardenRepository
        .watchMoments(userId: userId)
        .listen(
          (remoteMoments) {
            if (_disposed || currentUserId != userId) return;
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
      if (_disposed || currentUserId != uid) return;
      final unsynced = _entries
          .where((e) => entrySyncStatus(e.id) != EntrySyncStatus.synced)
          .toList();
      final localIds = unsynced.map((e) => e.id).toSet();
      _entries
        ..clear()
        ..addAll(remoteEntries.where((e) => !localIds.contains(e.id)))
        ..addAll(unsynced)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final remoteMoments = await _gardenRepository.fetchMoments(userId: uid);
      if (_disposed || revision != _sessionRevision) return;
      if (remoteMoments.isNotEmpty) {
        _gardenMoments
          ..clear()
          ..addAll(remoteMoments);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('MindraState: Error in syncFromApi ($e)');
    }
  }
}

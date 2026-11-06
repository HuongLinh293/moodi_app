import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/device_auth_service.dart';
import 'package:mindra/core/reminder_service.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/models/garden_moment.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/models/practice_record.dart';
import 'package:mindra/repositories/auth_repository.dart';
import 'package:mindra/repositories/garden_repository.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/repositories/practice_repository.dart';
import 'package:mindra/repositories/reflection_repository.dart';
import 'package:mindra/state/mindra_state.dart';

class SignedAuth extends AuthRepository {
  SignedAuth([this.uid = 'owner']);
  final String uid;
  @override
  AuthUser get currentUser => AuthUser(id: uid, email: '$uid@example.invalid');
  @override
  String get currentUserId => uid;
  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();
  @override
  Future<void> signOut() async {}
}

class LocalJournal extends JournalRepository {
  final changes = StreamController<List<JournalEntry>>.broadcast(sync: true);
  bool offline = true;
  @override
  Stream<List<JournalEntry>> watchEntries({String? userId}) => changes.stream;
  @override
  Future<List<JournalEntry>> fetchEntries({String? userId}) async => [];
  @override
  Future<void> saveEntry(JournalEntry e, {String? userId}) async {
    if (offline) throw StateError('offline');
  }

  @override
  Future<void> deleteEntry(String entryId, {String? userId}) async {}
  @override
  Future<void> deleteAllEntries({required String userId}) async {}
}

class LocalGarden extends GardenRepository {
  @override
  Stream<List<GardenMoment>> watchMoments({String? userId}) =>
      const Stream.empty();
  @override
  Future<List<GardenMoment>> fetchMoments({String? userId}) async => [];
  @override
  Future<void> deleteAllMoments({required String userId}) async {}
}

class LocalPractice extends PracticeRepository {
  @override
  Future<void> save(PracticeRecord record) async => throw StateError('offline');
  @override
  Future<List<PracticeRecord>> fetch() async => [];
}

class LocalReflections extends ReflectionRepository {
  @override
  Future<Map<String, AIReflection>> getReflectionsByEntry({
    int limit = 50,
  }) async => {};
}

class DeviceAuthFake extends DeviceAuthService {
  bool accepts = true;
  @override
  Future<bool> authenticate() async => accepts;
}

class ReminderFake extends ReminderService {
  bool succeeds = true;
  @override
  Future<bool> schedule(String time) async => succeeds;
}

JournalEntry sample(String id, {DateTime? time}) => JournalEntry(
  id: id,
  timestamp: time ?? DateTime.now(),
  emotionKey: 'happy',
  intensity: 4,
  situation: 'Nội dung riêng',
  thought: 'Suy nghĩ gốc',
);

void main() {
  MindraState make(
    LocalJournal journal, {
    List<JournalEntry>? entries,
    DeviceAuthFake? auth,
    ReminderFake? reminder,
    String uid = 'owner',
  }) => MindraState(
    initialEntries: entries,
    authRepository: SignedAuth(uid),
    journalRepository: journal,
    gardenRepository: LocalGarden(),
    practiceRepository: LocalPractice(),
    reflectionRepository: LocalReflections(),
    deviceAuth: auth,
    reminderService: reminder,
  );

  test('the first happy choice notifies immediately', () {
    final state = MindraState(isAuthenticated: false);
    addTearDown(state.dispose);
    var notifications = 0;
    state.addListener(() => notifications++);
    state.selectEmotion('happy');
    expect(state.hasChosenEmotion, isTrue);
    expect(notifications, 1);
  });

  test('AI consent belongs to an account and defaults to off for another user', () async {
    final repo = LocalJournal();
    final first = make(repo, entries: [sample('seed')]);
    addTearDown(first.dispose); addTearDown(repo.changes.close);
    first.setAiConsent(true);
    await Future<void>.delayed(Duration.zero);
    final otherRepo = LocalJournal();
    final other = make(otherRepo, entries: [sample('other')], uid: 'other');
    addTearDown(other.dispose); addTearDown(otherRepo.changes.close);
    await other.loadAiConsent();
    expect(other.aiConsent, isFalse);
    final restoredRepo = LocalJournal();
    final restored = make(restoredRepo, entries: [sample('seed')]);
    addTearDown(restored.dispose); addTearDown(restoredRepo.changes.close);
    await restored.loadAiConsent();
    expect(restored.aiConsent, isTrue);
  });

  test(
    'a failed journal write survives restart and stays owned by its account',
    () async {
      final firstRepo = LocalJournal();
      final first = make(firstRepo, entries: [sample('seed')]);
      first.addEntry(sample('unsent'));
      await first.flushLocalData();
      await Future<void>.delayed(Duration.zero);
      expect(first.entrySyncStatus('unsent'), EntrySyncStatus.failed);
      expect(first.isEntryOnDevice('unsent'), isTrue);
      first.dispose();
      await firstRepo.changes.close();
      final secondRepo = LocalJournal();
      final second = make(secondRepo);
      addTearDown(second.dispose);
      addTearDown(secondRepo.changes.close);
      await Future<void>.delayed(Duration.zero);
      expect(second.entryById('unsent')?.thought, 'Suy nghĩ gốc');
      expect(second.entrySyncStatus('unsent'), EntrySyncStatus.failed);
      final otherRepo = LocalJournal();
      final other = make(otherRepo, uid: 'other');
      addTearDown(other.dispose);
      addTearDown(otherRepo.changes.close);
      await Future<void>.delayed(Duration.zero);
      expect(other.entries, isEmpty);
    },
  );

  test(
    'a stale read cannot remove a write that has just been acknowledged',
    () async {
      final repo = LocalJournal()..offline = false;
      final state = make(repo);
      addTearDown(state.dispose);
      addTearDown(repo.changes.close);
      await Future<void>.delayed(Duration.zero);
      repo.changes.add([]);
      final entry = sample('new');
      state.addEntry(entry);
      await state.flushLocalData();
      await Future<void>.delayed(Duration.zero);
      expect(state.entrySyncStatus(entry.id), EntrySyncStatus.synced);
      repo.changes.add([]); // Request started before the write.
      expect(state.entryById(entry.id), isNotNull);
      repo.changes.add([entry]); // Server has now observed this version.
      repo.changes.add(
        [],
      ); // A later deletion from another device is respected.
      expect(state.entryById(entry.id), isNull);
    },
  );

  test(
    'multiple practice sessions keep journal text and unknown emotions intact',
    () async {
      final repo = LocalJournal();
      final original = sample('source');
      final state = make(repo, entries: [original]);
      addTearDown(state.dispose);
      addTearDown(repo.changes.close);
      state.recordPractice(
        exerciseId: 'response-pause',
        note: 'Chưa rõ cảm xúc',
      );
      state.recordPractice(
        exerciseId: 'grounding',
        sourceEntryId: original.id,
        beforeEmotionKey: original.emotionKey,
        beforeIntensity: original.intensity,
        afterEmotionKey: 'sad',
        afterIntensity: 5,
      );
      await state.flushLocalData();
      expect(state.entries.single.thought, original.thought);
      expect(state.entries.single.exerciseDone, isFalse);
      expect(state.practiceRecords, hasLength(2));
      expect(state.practiceRecords.last.afterEmotionKey, isNull);
      expect(
        state.practiceRecords.first.afterIntensity,
        5,
      ); // No forced improvement.
      expect(state.exercisesCompleted, 2);
    },
  );

  test('an empty current week never borrows historical statistics', () {
    final repo = LocalJournal();
    final state = make(
      repo,
      entries: [
        sample('old', time: DateTime.now().subtract(const Duration(days: 40))),
      ],
    );
    addTearDown(state.dispose);
    addTearDown(repo.changes.close);
    expect(state.checkinDaysThisWeek, 0);
    expect(state.averageIntensityThisWeek, 0);
    expect(state.dominantEmotionThisWeek, isNull);
    expect(state.dominantTriggerThisWeek, isNull);
  });

  test(
    'edited reflections survive restart and are removed with their journal',
    () async {
      final repo = LocalJournal()..offline = false;
      final first = make(repo, entries: [sample('seed')]);
      first.addEntry(sample('reflected'));
      await first.flushLocalData();
      await Future<void>.delayed(Duration.zero);
      first.updateAIReflection(
        'reflected',
        AIReflection.forEmotion(emotionKey: 'happy', intensity: 4).copyWith(
          balancedThought: 'Lời do tôi sửa',
          userFeedback: 'needs_edit',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      first.dispose();
      await repo.changes.close();
      final nextRepo = LocalJournal();
      final next = make(nextRepo);
      addTearDown(next.dispose);
      addTearDown(nextRepo.changes.close);
      await Future<void>.delayed(Duration.zero);
      expect(
        next.reflectionForEntry('reflected')?.balancedThought,
        'Lời do tôi sửa',
      );
      await next.removeEntry('reflected');
      expect(next.reflectionForEntry('reflected'), isNull);
      expect(next.exportPersonalData()['reflections'], isEmpty);
    },
  );

  test('failed rescheduling keeps the time already scheduled', () async {
    final reminder = ReminderFake();
    final repo = LocalJournal();
    final state = make(repo, entries: [sample('e')], reminder: reminder);
    addTearDown(state.dispose);
    addTearDown(repo.changes.close);
    expect(await state.setReminderEnabled(true), isTrue);
    reminder.succeeds = false;
    expect(await state.setReminderTime('08:30'), isFalse);
    expect(state.reminderTime, '21:00');
    expect(state.reminderEnabled, isTrue);
  });

  test('device lock requires authentication, persists, and relocks', () async {
    final device = DeviceAuthFake();
    final repo = LocalJournal();
    final state = make(repo, entries: [sample('e')], auth: device);
    addTearDown(state.dispose);
    addTearDown(repo.changes.close);
    device.accepts = false;
    expect(await state.setAppLockEnabled(true), isFalse);
    expect(state.appLockEnabled, isFalse);
    device.accepts = true;
    expect(await state.setAppLockEnabled(true), isTrue);
    state.lockApplication();
    expect(state.appUnlocked, isFalse);
    device.accepts = false;
    expect(await state.unlockApplication(), isFalse);
    expect(state.appUnlocked, isFalse);
    device.accepts = true;
    expect(await state.unlockApplication(), isTrue);
    final nextRepo = LocalJournal();
    final next = make(nextRepo, entries: [sample('e')]);
    addTearDown(next.dispose);
    addTearDown(nextRepo.changes.close);
    await next.loadLocalPreferences();
    expect(next.appLockEnabled, isTrue);
    expect(next.appUnlocked, isFalse);
  });

  test(
    'export includes practice, reflection and every journal feedback field',
    () {
      final repo = LocalJournal();
      final state = make(
        repo,
        entries: [
          sample('e').copyWith(
            exerciseId: 'grounding',
            afterEmotionKey: 'calm',
            afterIntensity: 2,
            usefulnessRating: 4,
            easeRating: 3,
            repeatPreference: 'maybe',
          ),
        ],
      );
      addTearDown(state.dispose);
      addTearDown(repo.changes.close);
      final data = state.exportPersonalData();
      final row = (data['entries'] as List).single as Map;
      expect(data['schemaVersion'], 1);
      expect(row['afterEmotionKey'], 'calm');
      expect(row['usefulnessRating'], 4);
      expect(row['repeatPreference'], 'maybe');
      expect(
        data.keys,
        containsAll([
          'practiceRecords',
          'microGoals',
          'reflections',
          'gardenMoments',
        ]),
      );
    },
  );
}

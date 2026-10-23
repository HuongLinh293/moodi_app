import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mindra/main.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/models/garden_moment.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/models/shared_garden.dart';
import 'package:mindra/repositories/auth_repository.dart';
import 'package:mindra/repositories/garden_repository.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/repositories/reflection_repository.dart';
import 'package:mindra/repositories/shared_garden_repository.dart';
import 'package:mindra/screens/home_shell.dart';
import 'package:mindra/screens/login_view.dart';
import 'package:mindra/state/mindra_state.dart';

class TestUser implements AuthUser {
  TestUser(this.uid);
  final String uid;
  @override
  String get id => uid;
  @override
  String get email => '$uid@example.invalid';
  @override
  String get displayName => uid;
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SessionAuth extends AuthRepository {
  AuthUser? user = TestUser('alice');
  bool failLogout = false;
  final changes = StreamController<AuthUser?>.broadcast(sync: true);
  @override
  AuthUser? get currentUser => user;
  @override
  String? get currentUserId => user?.id;
  @override
  Stream<AuthUser?> get authStateChanges => changes.stream;
  void switchTo(String? uid) {
    user = uid == null ? null : TestUser(uid);
    changes.add(user);
  }

  @override
  Future<void> signOut() async {
    if (failLogout) throw StateError('Simulated auth failure');
    switchTo(null);
  }
}

class SessionJournal extends JournalRepository {
  final streams = <String, StreamController<List<JournalEntry>>>{};
  final pending = Completer<void>();
  @override
  Stream<List<JournalEntry>> watchEntries({String? userId}) => streams
      .putIfAbsent(
        userId!,
        () => StreamController<List<JournalEntry>>.broadcast(sync: true),
      )
      .stream;
  @override
  Future<void> saveEntry(JournalEntry entry, {String? userId}) =>
      pending.future;
  @override
  Future<List<JournalEntry>> fetchEntries({String? userId}) async => [];
}

class SessionGarden extends GardenRepository {
  final pendingFetch = Completer<List<GardenMoment>>();
  @override
  Stream<List<GardenMoment>> watchMoments({String? userId}) =>
      const Stream.empty();
  @override
  Future<List<GardenMoment>> fetchMoments({String? userId}) =>
      pendingFetch.future;
}

class SessionShared extends SharedGardenRepository {
  @override
  Stream<SharedGarden?> watchUserGarden(String userId) => const Stream.empty();
}

class SessionReflection extends ReflectionRepository {
  final pending = Completer<AIReflection>();
  @override
  Future<AIReflection> generateReflection({
    required String emotionKey,
    required int intensity,
    String? situation,
    String? thought,
    String? entryId,
  }) => pending.future;
}

JournalEntry entry(String id) => JournalEntry(
  id: id,
  timestamp: DateTime(2026, 10, 19),
  emotionKey: 'calm',
  intensity: 3,
);
AIReflection reflection() =>
    AIReflection.forEmotion(emotionKey: 'calm', intensity: 3);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late SessionAuth auth;
  late SessionJournal journal;
  late SessionGarden garden;
  late SessionReflection reflections;
  late MindraState state;
  setUp(() {
    auth = SessionAuth();
    journal = SessionJournal();
    garden = SessionGarden();
    reflections = SessionReflection();
    state = MindraState(
      authRepository: auth,
      journalRepository: journal,
      gardenRepository: garden,
      sharedGardenRepository: SessionShared(),
      reflectionRepository: reflections,
    );
  });
  tearDown(() async {
    state.dispose();
    await auth.changes.close();
    for (final stream in journal.streams.values) {
      await stream.close();
    }
    if (!journal.pending.isCompleted) journal.pending.complete();
  });
  test(
    'SESSION-01 switching accounts clears private caches and unsynced writes',
    () async {
      state.addEntry(entry('private-a'));
      state.cacheAIReflection('private-a', reflection());
      state.addMicroGoal('Private goal');
      state.saveWeeklyReview(
        mostFrequent: 'Private',
        helped: 'Private',
        nextWeek: 'Private',
      );
      auth.switchTo('bob');
      journal.pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(state.entries, isEmpty);
      expect(state.gardenMoments, isEmpty);
      expect(state.microGoals, isEmpty);
      expect(state.weeklyReview, isNull);
      expect(state.reflectionForEntry('private-a'), isNull);
      expect(state.pendingEntryCount, 0);
      journal.streams['alice']!.add([entry('stale-a')]);
      expect(state.entries, isEmpty);
      journal.streams['bob']!.add([entry('private-b')]);
      expect(state.entries.single.id, 'private-b');
    },
  );
  test('SESSION-02 late reflection cannot enter the next session, even A -> B -> A', () async {
    final pending = state.fetchOrGenerateAIReflection(entry('old'));
    final rejected = expectLater(pending, throwsStateError);
    auth.switchTo('bob');
    auth.switchTo('alice');
    reflections.pending.complete(reflection());
    await rejected;
    expect(state.reflectionForEntry('old'), isNull);
  });
  test(
    'SESSION-03 late garden fetch cannot populate the next session',
    () async {
      final pending = state.syncFromApi();
      await Future<void>.delayed(Duration.zero);
      auth.switchTo('bob');
      auth.switchTo('alice');
      garden.pendingFetch.complete([
        GardenMoment(
          id: 'old',
          entryId: 'old',
          monthKey: '2026-10',
          bedIndex: 0,
          slotIndex: 0,
          plantedAt: DateTime(2026, 10, 19),
        ),
      ]);
      await pending;
      expect(state.gardenMoments, isEmpty);
    },
  );
  test('SESSION-04 failed logout keeps valid session; successful logout clears caches', () async {
    journal.streams['alice']!.add([entry('private-a')]);
    state.cacheAIReflection('private-a', reflection());
    auth.failLogout = true;
    await expectLater(state.logout(), throwsStateError);
    expect(state.isAuthenticated, isTrue);
    expect(state.entries.single.id, 'private-a');
    auth.failLogout = false;
    await state.logout();
    expect(state.isAuthenticated, isFalse);
    expect(state.entries, isEmpty);
    expect(state.reflectionForEntry('private-a'), isNull);
  });
  testWidgets('SESSION-05 logout removes pushed private routes', (
    tester,
  ) async {
    await tester.pumpWidget(MindraApp(state: state));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeShell));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Sensitive detail route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sensitive detail route'), findsOneWidget);
    await state.logout();
    await tester.pumpAndSettle();
    expect(find.text('Sensitive detail route'), findsNothing);
    expect(find.byType(LoginView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('SESSION-06 repositories reject missing UID instead of using a global collection', () async {
    await expectLater(
      JournalRepository().saveEntry(entry('x')),
      throwsStateError,
    );
    await expectLater(
      GardenRepository().saveMoment(
        GardenMoment(
          id: 'x',
          entryId: 'x',
          monthKey: '2026-10',
          bedIndex: 0,
          slotIndex: 0,
          plantedAt: DateTime(2026, 10, 19),
        ),
      ),
      throwsStateError,
    );
  });
}

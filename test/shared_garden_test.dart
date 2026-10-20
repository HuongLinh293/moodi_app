import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/theme/theme.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/models/shared_garden.dart';

import 'helpers/fake_shared_garden_repository.dart';
import 'package:mindra/widgets/shared_garden_widgets.dart';

import 'package:mindra/repositories/garden_repository.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/repositories/shared_garden_repository.dart';
import 'package:mindra/screens/garden_view.dart';
import 'package:mindra/state/mindra_state.dart';

class _NoopJournal extends JournalRepository {
  @override
  Future<void> deleteEntry(String entryId, {String? userId}) async {}
  @override
  Future<void> deleteAllEntries({required String userId}) async {}
}

class _NoopGarden extends GardenRepository {
  @override
  Future<void> deleteAllMoments({required String userId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Repository errors are not converted to fake success', () async {
    final repo = SharedGardenRepository();
    await expectLater(
      repo.createGarden(userId: 'user_1', userName: 'Linh'),
      throwsA(anything),
    );
    await expectLater(
      repo.plantEntry('garden-1', 'entry-1'),
      throwsA(anything),
    );
  });

  test('Restores membership, replaces snapshots, isolates gardens and persists leave', () async {
    final repo = FakeSharedGardenRepository();
    final auth = GardenTestAuth();
    final state = MindraState(
      initialEntries: [
        JournalEntry(
          id: 'entry-1',
          timestamp: DateTime.now(),
          emotionKey: 'calm',
          intensity: 3,
        ),
      ],
      authRepository: auth,
      sharedGardenRepository: repo,
    );
    addTearDown(state.dispose);
    state.retrySharedGarden();
    final garden = await repo.createGarden(userId: 'user_1', userName: 'Linh');
    expect(state.sharedGarden?.id, garden.id);
    await state.plantInSharedGarden('entry-1');
    expect(state.sharedMoments, hasLength(1));
    repo.streams[garden.id]!.add([]);
    expect(state.sharedMoments, isEmpty);
    await state.plantInSharedGarden('entry-1');
    final other = SharedGarden(
      id: 'garden-2',
      code: 'new',
      name: 'Vườn khác',
      members: ['user_1'],
      memberNames: {},
      createdAt: DateTime.now(),
    );
    repo.membership.add(other);
    expect(state.sharedMoments, isEmpty);
    repo.streams[garden.id]!.add(List.of(repo.items));
    expect(state.sharedMoments, isEmpty);
    repo.fail = true;
    await expectLater(state.leaveSharedGarden(), throwsStateError);
    expect(state.sharedGarden?.id, 'garden-2');
    await expectLater(state.plantInSharedGarden('entry-1'), throwsStateError);
    expect(state.sharedMoments, isEmpty);
    repo.fail = false;
    await state.leaveSharedGarden();
    expect(repo.leaves, 1);
    expect(state.sharedGarden, isNull);
    expect(state.sharedMoments, isEmpty);
  });

  test('Demo garden is local only: writes are refused and it can be left', () async {
    final repo = FakeSharedGardenRepository();
    final state = MindraState(
      initialEntries: [
        JournalEntry(id: 'a', timestamp: DateTime.now(), emotionKey: 'calm', intensity: 3),
      ],
      authRepository: GardenTestAuth(),
      sharedGardenRepository: repo,
    );
    addTearDown(state.dispose);
    state.loadDemoSharedGarden();
    expect(state.isDemoSharedGarden, isTrue);
    expect(state.sharedGarden!.members, hasLength(2));
    await expectLater(
      state.plantInSharedGarden('a'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('vườn mẫu'))),
    );
    await expectLater(
      state.sendCareReaction(momentId: state.sharedMoments.first.id, isWater: true),
      throwsStateError,
    );
    expect(repo.items, isEmpty);
    await state.leaveSharedGarden();
    expect(state.isDemoSharedGarden, isFalse);
    expect(repo.leaves, 0);
  });

  test('Authors can take back shared flowers when removing, deleting or leaving', () async {
    final repo = FakeSharedGardenRepository();
    JournalEntry entry(String id) => JournalEntry(
      id: id,
      timestamp: DateTime.now(),
      emotionKey: 'calm',
      intensity: 3,
    );
    final state = MindraState(
      initialEntries: [entry('a'), entry('b'), entry('c')],
      authRepository: GardenTestAuth(),
      sharedGardenRepository: repo,
      journalRepository: _NoopJournal(),
      gardenRepository: _NoopGarden(),
    );
    addTearDown(state.dispose);
    state.retrySharedGarden();
    await repo.createGarden(userId: 'user_1', userName: 'Linh');
    await state.plantInSharedGarden('a');
    await state.plantInSharedGarden('b');
    expect(state.isSharedPlanted('a'), isTrue);
    expect(state.isSharedPlanted('c'), isFalse);

    // Text stays private unless the user opted in on the preview.
    expect(state.sharedMoments.first.caption, isEmpty);

    await state.removeSharedMoment('user_1_a');
    expect(state.isSharedPlanted('a'), isFalse);

    // Deleting the journal entry takes its shared copy with it.
    await state.removeEntry('b');
    expect(repo.removed, ['user_1_a', 'user_1_b']);
    expect(state.isSharedPlanted('b'), isFalse);

    await state.plantInSharedGarden('c');
    await state.deleteAllUserData();
    expect(repo.removed.last, '${state.sharedGarden!.id}/*');

    await state.leaveSharedGarden(removeMyFlowers: true);
    expect(repo.removed.where((r) => r.endsWith('/*')), hasLength(2));
    expect(repo.leaves, 1);
  });

  testWidgets('More than twenty shared flowers use separate beds and remain tappable', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = MindraState();
    addTearDown(state.dispose);
    final moments = List.generate(22, (i) => SharedMoment(id: '$i', gardenId: 'garden', authorId: 'alice', authorName: 'Alice',
      emotionKey: 'calm', intensity: 3, caption: '', slotIndex: i % 20, bedIndex: i ~/ 20, monthKey: '2026-10', plantedAt: DateTime(2026, 10)));
    String? opened;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(
      child: SharedGardenBedView(state: state, moments: moments, onOpenMoment: (moment) => opened = moment.id)))));
    await tester.pumpAndSettle();
    expect(find.text('Luống 2'), findsOneWidget);
    for (final moment in moments) {
      final flower = find.byKey(ValueKey('shared-flower-${moment.id}'));
      await tester.ensureVisible(flower);
      await tester.tap(flower);
      expect(opened, moment.id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('GardenView renders personal garden directly without shared garden toggle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testEntry = JournalEntry(
      id: 'entry-1',
      timestamp: DateTime.now(),
      emotionKey: 'calm',
      intensity: 3,
      thought: 'Yên bình buổi sáng',
    );

    final state = MindraState(
      initialEntries: [testEntry],
      authRepository: GardenTestAuth(),
      sharedGardenRepository: FakeSharedGardenRepository(),
      isAuthenticated: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: GardenView(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    // Verify personal garden is default and there is no shared garden toggle
    expect(find.text('Vườn của tôi'), findsNothing);
    expect(find.text('Vườn sẻ chia'), findsNothing);
    expect(find.textContaining('Tháng'), findsOneWidget);
    expect(find.textContaining('Những điều bạn muốn giữ lại'), findsOneWidget);
  });
}

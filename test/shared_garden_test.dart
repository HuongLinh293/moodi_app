import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/theme/theme.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/models/shared_garden.dart';

import 'helpers/fake_shared_garden_repository.dart';
import 'package:mindra/widgets/shared_garden_widgets.dart';

import 'package:mindra/repositories/shared_garden_repository.dart';
import 'package:mindra/screens/garden_view.dart';
import 'package:mindra/state/mindra_state.dart';

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

  testWidgets('GardenView toggles to Shared Garden and renders UI', (
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

    // Verify personal garden is default
    expect(find.text('Vườn của tôi'), findsOneWidget);
    expect(find.text('Vườn sẻ chia'), findsOneWidget);

    // Switch to Shared Garden
    await tester.tap(find.text('Vườn sẻ chia'));
    await tester.pumpAndSettle();

    expect(state.isSharedGardenMode, isTrue);
    expect(find.text('Tạo khu vườn mới'), findsOneWidget);
    expect(find.text('Nhập mã kết nối'), findsOneWidget);

    // Tap Tạo khu vườn mới
    await tester.tap(find.text('Tạo khu vườn mới'));
    await tester.pumpAndSettle();

    expect(state.sharedGarden, isNotNull);
    expect(find.text('Khu vườn đã sẵn sàng! 🌱'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Vào vườn ngay'));
    await tester.pumpAndSettle();

    expect(find.text('Gieo cảm xúc vào vườn chung'), findsOneWidget);
    expect(find.text('Bưu thiếp kỷ niệm'), findsOneWidget);

    // Open Postcard dialog
    await tester.ensureVisible(find.text('Bưu thiếp kỷ niệm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bưu thiếp kỷ niệm'));
    await tester.pumpAndSettle();

    expect(find.text('BƯU THIẾP TÂM TRÍ'), findsOneWidget);
    expect(find.text('Đóng'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    // Plant entry into shared garden
    await tester.ensureVisible(find.text('Gieo cảm xúc vào vườn chung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gieo cảm xúc vào vườn chung'));
    await tester.pumpAndSettle();

    expect(find.text('Gieo vào vườn sẻ chia'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();

    // Verify flower is rendered in the garden bed
    expect(state.sharedMoments.length, 1);
    expect(
      find.byKey(ValueKey('shared-flower-${state.sharedMoments.first.id}')),
      findsOneWidget,
    );
    expect(
      find.text('1 khoảnh khắc được cùng nhau gieo trồng'),
      findsOneWidget,
    );

    // Wait for SnackBar to dismiss
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Open postcard and verify stats updated
    await tester.ensureVisible(find.text('Bưu thiếp kỷ niệm'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bưu thiếp kỷ niệm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bưu thiếp kỷ niệm'));
    await tester.pumpAndSettle();

    expect(find.text('1 🌸'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
  });
}

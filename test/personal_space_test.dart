import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/screens/personal_space_view.dart';
import 'package:mindra/state/mindra_state.dart';

Widget _host(MindraState state) {
  // HomeShell rebuilds the tab via context.watch; mirror that here.
  return MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(
        listenable: state,
        builder: (_, _) => PersonalSpaceView(state: state, onOpenCheckin: () {}),
      ),
    ),
  );
}

String _dateHeader(DateTime dt) {
  const viDays = [
    '',
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${viDays[dt.weekday]}, ${dt.day} tháng ${dt.month}';
}

void main() {
  testWidgets('"Xem trong vườn" opens the garden at the entry month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 10, 9);
    final state = MindraState()..clearAllData();
    addTearDown(state.dispose);
    state.addEntry(
      JournalEntry(
        id: 'old-calm',
        timestamp: lastMonth,
        emotionKey: 'calm',
        intensity: 2,
        situation: 'Đi dạo buổi sáng.',
      ),
    );
    await state.plantMoment('old-calm');

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Ngày 10 tháng ${lastMonth.month}: Bình yên'),
    );
    await tester.pumpAndSettle();

    final viewInGarden = find.text('Xem trong vườn');
    await tester.ensureVisible(viewInGarden);
    await tester.pumpAndSettle();
    await tester.tap(viewInGarden);
    await tester.pumpAndSettle();

    expect(find.text('Tháng ${lastMonth.month} của bạn'), findsOneWidget);
  });

  testWidgets('Journal cannot move into or select future days', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final state = MindraState()..clearAllData();
    addTearDown(state.dispose);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('THÁNG ${now.month} ', findRichText: true), findsOneWidget);

    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (tomorrow.month == now.month) {
      await tester.tap(
        find.byTooltip(
          'Ngày ${tomorrow.day} tháng ${tomorrow.month}: Chưa có ghi chép',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_dateHeader(tomorrow)), findsNothing);
      expect(find.text(_dateHeader(now)), findsOneWidget);
    }
  });
}

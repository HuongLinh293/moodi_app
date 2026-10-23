import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/widgets/mood_trend_card.dart';

void main() {
  final now = DateTime.now();
  final entries = [
    JournalEntry(id: 'a', timestamp: now, emotionKey: 'calm', intensity: 2),
    JournalEntry(
      id: 'b',
      timestamp: now.subtract(const Duration(days: 2)),
      emotionKey: 'sad',
      intensity: 4,
    ),
    JournalEntry(
      id: 'c',
      timestamp: now.subtract(const Duration(days: 20)),
      emotionKey: 'happy',
      intensity: 5,
    ),
  ];

  Future<void> pump(WidgetTester tester, double textScale) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(18),
              child: MoodTrendCard(entries: entries),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows 7-day summary and switches to 30 days', (tester) async {
    await pump(tester, 1);
    expect(find.text('XU HƯỚNG CẢM XÚC'), findsOneWidget);
    expect(find.textContaining('Có mặt 2/7 ngày'), findsOneWidget);
    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Có mặt 3/30 ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a narrow screen with enlarged text', (tester) async {
    await pump(tester, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/main.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/screens/ai_reflection_view.dart';
import 'package:mindra/screens/checkin_view.dart';
import 'package:mindra/screens/journal_view.dart';
import 'package:mindra/screens/practice_session.dart';
import 'package:mindra/state/mindra_state.dart';

import 'helpers/test_data.dart';

void main() {
  Future<void> phone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  MindraState stateWithHistory() =>
      MindraState(initialEntries: TestData.getInitialEntries())
        ..setLowStimulationMode(true)
        ..setAiConsent(true);

  testWidgets('first happy selection immediately enables check-in', (
    tester,
  ) async {
    final state = MindraState(isAuthenticated: false)
      ..setLowStimulationMode(true);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckinView(state: state, onOpenJournal: () {}),
        ),
      ),
    );
    expect(find.text('Chưa chọn cảm xúc'), findsOneWidget);
    await tester.tap(find.text('Vui'));
    await tester.pump();
    expect(find.text('Chưa chọn cảm xúc'), findsNothing);
    final save = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Lưu check-in nhanh'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('check-in reflection returns safely to the journal', (
    tester,
  ) async {
    await phone(tester);
    final state = stateWithHistory()..selectEmotion('calm');
    addTearDown(state.dispose);
    state.addListener(() {
      for (final entry in state.entries) {
        state.cacheAIReflection(
          entry.id,
          AIReflection.forEmotion(
            emotionKey: entry.emotionKey,
            intensity: entry.intensity,
          ),
        );
      }
    });
    await tester.pumpWidget(MindraApp(state: state));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ghi nhận thêm'));
    await tester.tap(find.text('Ghi nhận thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đầy đủ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu & Xem gợi ý phản tư'));
    await tester.tap(find.text('Lưu & Xem gợi ý phản tư'));
    await tester.pumpAndSettle();
    expect(find.byType(AIReflectionView), findsOneWidget);
    await tester.ensureVisible(find.text('Xem trong Lịch & Nhật ký →'));
    await tester.tap(find.text('Xem trong Lịch & Nhật ký →'));
    await tester.pumpAndSettle();
    expect(find.byType(AIReflectionView), findsNothing);
    expect(find.byType(JournalView), findsOneWidget);
    expect(state.currentTab, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing a written check-in asks before discarding', (
    tester,
  ) async {
    await phone(tester);
    final state = stateWithHistory()..selectEmotion('calm');
    addTearDown(state.dispose);
    final count = state.entries.length;
    await tester.pumpWidget(MindraApp(state: state));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ghi nhận thêm'));
    await tester.tap(find.text('Ghi nhận thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đầy đủ'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('Suy nghĩ tự động')),
      'Nội dung đang viết',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đóng check-in'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ nội dung đang viết?'), findsOneWidget);
    await tester.tap(find.text('Viết tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung đang viết'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ nội dung'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckinView), findsNothing);
    expect(state.entries.length, count);
  });

  testWidgets('explore keeps the practice section after another tab', (
    tester,
  ) async {
    final state = stateWithHistory()..setTab(3);
    addTearDown(state.dispose);
    await tester.pumpWidget(MindraApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thực hành'));
    await tester.pumpAndSettle();
    state.setTab(0);
    await tester.pumpAndSettle();
    state.setTab(3);
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu viết'), findsOneWidget);
    expect(find.text('TIẾN TRÌNH CỦA BẠN'), findsNothing);
  });

  testWidgets('optional practice ratings can be selected and cleared', (
    tester,
  ) async {
    await phone(tester);
    final state = stateWithHistory();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeSessionSheet(
            state: state,
            config: const PracticeSessionConfig(
              id: 'grounding',
              title: 'Neo về hiện tại',
              purpose: 'Quan sát quanh bạn.',
              durationLabel: '1 phút',
              accent: Colors.blue,
              kind: PracticeKind.steps,
              prompts: [
                PracticePrompt(
                  title: 'Quan sát',
                  body: 'Nhìn một vật quanh bạn.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành bài tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-in lại cảm xúc'));
    await tester.pumpAndSettle();
    final value = find.descendant(
      of: find.byKey(const ValueKey('exercise-usefulness')),
      matching: find.text('4'),
    );
    await tester.ensureVisible(value);
    await tester.tap(value);
    await tester.pumpAndSettle();
    await tester.tap(value);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey('exercise-usefulness')),
          )
          .selected,
      isEmpty,
    );
    expect(state.practiceRecords, hasLength(1));
    expect(state.practiceRecords.single.afterEmotionKey, isNull);
    expect(tester.takeException(), isNull);
  });
}

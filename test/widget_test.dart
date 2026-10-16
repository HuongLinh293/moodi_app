import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/main.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/models/micro_goal.dart';
import 'package:mindra/screens/ai_reflection_view.dart';
import 'package:mindra/screens/checkin_view.dart';
import 'package:mindra/screens/garden_view.dart';
import 'package:mindra/screens/home_shell.dart';
import 'package:mindra/screens/journal_view.dart';
import 'package:mindra/screens/practice_session.dart';
import 'package:mindra/screens/progress_view.dart';
import 'package:mindra/screens/login_view.dart';
import 'package:mindra/screens/onboarding_view.dart';
import 'package:provider/provider.dart';
import 'package:mindra/state/mindra_state.dart';
import 'helpers/test_data.dart';

MindraState createTestState() {
  return MindraState(
    initialEntries: TestData.getInitialEntries(),
    initialMicroGoals: [
      MicroGoal(
        id: 'mg-1',
        prompt:
            'Khi cảm thấy căng thẳng dồn dập, tôi sẽ dừng lại 30 giây và hít thở sâu 3 nhịp.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
    isAuthenticated: true,
  )..completeOnboarding();
}

void main() {
  testWidgets('Fresh launch shows onboarding before login', (tester) async {
    final state = MindraState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MindraApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingView), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);

    state.completeOnboarding();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingView), findsNothing);
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('Planted moment confirmation dismisses automatically', (
    tester,
  ) async {
    final state = MindraState()..clearAllData();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckinView(state: state, onOpenJournal: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu check-in nhanh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giữ trong vườn'));
    await tester.pumpAndSettle();
    expect(state.gardenMoments, hasLength(1));
    expect(find.text('Khoảnh khắc đã được giữ lại.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Mindra app launches and shows HomeShell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MindraApp(state: createTestState()));
    await tester.pumpAndSettle();

    // The app should render without errors
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('Home shell fits a narrow screen and shows four destinations', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MindraApp(state: createTestState()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Nhật ký'), findsOneWidget);
    expect(find.text('Khu vườn'), findsOneWidget);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Tôi'), findsOneWidget);
    expect(find.text('MOODI GARDEN'), findsOneWidget);
    expect(find.text('Xem thêm cảm xúc'), findsNothing);
    expect(find.text('Pause Mode (30s)'), findsOneWidget);

    final openGardenButton = find.text('Mở khu vườn');
    await tester.ensureVisible(openGardenButton);
    await tester.pumpAndSettle();
    await tester.tap(openGardenButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Những điều bạn muốn giữ lại'), findsWidgets);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

    await tester.tap(find.text('Nhật ký').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.calendar_view_month_rounded), findsOneWidget);

    await tester.tap(find.text('Khám phá').last);
    await tester.pumpAndSettle();
    expect(find.text('TIẾN TRÌNH CỦA BẠN'), findsOneWidget);
    expect(find.text('Thực hành'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty Progress opens the Check-in callback', (
    WidgetTester tester,
  ) async {
    final state = MindraState()..clearAllData();
    var openedCheckin = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressView(
            state: state,
            onOpenCheckin: () => openedCheckin = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bắt đầu check-in'));

    expect(openedCheckin, isTrue);
  });

  testWidgets('Home supports enlarged text on a narrow screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(MindraApp(state: createTestState()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Garden flower opens its meaning and bloom condition', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = MindraState()..clearAllData();
    state.addEntry(
      JournalEntry(
        id: 'garden-calm',
        timestamp: DateTime.now(),
        emotionKey: 'calm',
        intensity: 2,
        situation: 'Dành 15 phút buổi sáng uống trà.',
      ),
    );
    state.plantMoment('garden-calm');

    await tester.pumpWidget(MaterialApp(home: GardenView(state: state)));
    await tester.pumpAndSettle();

    final flower = find.byKey(const ValueKey('garden-flower-garden-calm'));
    await tester.ensureVisible(flower);
    await tester.pumpAndSettle();
    await tester.tap(flower);
    await tester.pumpAndSettle();

    expect(find.text('Bình yên'), findsWidgets);
    expect(
      find.textContaining('Dành 15 phút buổi sáng uống trà.'),
      findsOneWidget,
    );
    expect(find.text('Đóng'), findsOneWidget);
  });

  testWidgets('Redesigned garden keeps every bloom tappable on small phones', (
    tester,
  ) async {
    final state = createTestState();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 375.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GardenView(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      for (final moment in state.momentsInMonth(
        state.currentGardenMonthKey(),
      )) {
        final flower = find.byKey(ValueKey('garden-flower-${moment.entryId}'));
        await tester.ensureVisible(flower);
        await tester.pumpAndSettle();
        await tester.tap(flower);
        await tester.pumpAndSettle();
        expect(find.text('Đóng'), findsOneWidget);
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Quick check-in saves emotion and intensity without text fields',
    (WidgetTester tester) async {
      final state = MindraState()..clearAllData();
      final initialCount = state.entries.length;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckinView(state: state, onOpenJournal: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Lưu check-in nhanh'), findsOneWidget);

      await tester.tap(find.text('Lưu check-in nhanh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(state.entries.length, initialCount + 1);
      expect(state.entries.first.situation, isEmpty);
      expect(state.entries.first.thought, isEmpty);
      expect(state.entries.first.response, isEmpty);
    },
  );

  testWidgets('Full check-in collects and saves separate reflection fields', (
    WidgetTester tester,
  ) async {
    final state = createTestState();
    final initialCount = state.entries.length;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckinView(state: state, onOpenJournal: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đầy đủ'));
    await tester.pumpAndSettle();

    final situationField = find.byKey(const ValueKey('Tình huống'));
    final thoughtField = find.byKey(const ValueKey('Suy nghĩ tự động'));
    final responseField = find.byKey(const ValueKey('Phản ứng'));
    expect(situationField, findsOneWidget);
    expect(thoughtField, findsOneWidget);
    expect(responseField, findsOneWidget);

    await tester.enterText(situationField, 'Nhận góp ý trong buổi họp');
    await tester.enterText(thoughtField, 'Mình chưa làm đủ tốt');
    await tester.enterText(responseField, 'Mình im lặng một lúc');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chỉ lưu check-in này'));
    await tester.tap(find.text('Chỉ lưu check-in này'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(state.entries.length, initialCount + 1);
    expect(state.entries.first.situation, 'Nhận góp ý trong buổi họp');
    expect(state.entries.first.thought, 'Mình chưa làm đủ tốt');
    expect(state.entries.first.response, 'Mình im lặng một lúc');
  });

  testWidgets('Micro-goal follow-up can be skipped, retried and noted', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MindraApp(state: createTestState()));
    await tester.pumpAndSettle();

    final notTriedButton = find.text('Chưa thử lần này');
    await tester.ensureVisible(notTriedButton);
    await tester.pumpAndSettle();
    await tester.tap(notTriedButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Không sao. Bạn có thể quay lại bước này khi thấy phù hợp.'),
      findsOneWidget,
    );

    final retryButton = find.text('Thử lại sau');
    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã thử bước nhỏ này chưa?'), findsOneWidget);

    final triedButton = find.text('Đã thử');
    await tester.ensureVisible(triedButton);
    await tester.pumpAndSettle();
    await tester.tap(triedButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Cảm ơn bạn đã ghi nhận, dù kết quả thế nào.'),
      findsOneWidget,
    );

    final noteButton = find.text('Ghi chú tùy chọn');
    await tester.ensureVisible(noteButton);
    await tester.pumpAndSettle();
    await tester.tap(noteButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Mình đã dừng lại trước khi trả lời.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Mình đã dừng lại trước khi trả lời.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI reflection can be edited and its suggestions dismissed', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = createTestState();
    final entry = JournalEntry(
      id: 'reflection-test',
      timestamp: DateTime.now(),
      emotionKey: 'stressed',
      intensity: 4,
      situation: 'Góp ý trong buổi họp',
      thought: 'Mình phải làm mọi thứ hoàn hảo',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AIReflectionView(
                      entry: entry,
                      state: state,
                      onOpenJournal: () {},
                    ),
                  ),
                ),
                child: const Text('Mở phản tư'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở phản tư'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final needsEdit = find.text('Cần sửa ✏️');
    await tester.ensureVisible(needsEdit);
    await tester.pump();
    await tester.tap(needsEdit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Chỉnh sửa phản tư'), findsOneWidget);

    final emotionsField = find.byKey(
      const ValueKey('Cảm xúc có thể liên quan, cách nhau bằng dấu phẩy'),
    );
    expect(emotionsField, findsOneWidget);
    await tester.enterText(emotionsField, 'Áp lực đã chỉnh, Lo lắng');
    tester.testTextInput.hide();
    await tester.pump();
    final saveEdits = find.text('Lưu chỉnh sửa');
    await tester.tap(saveEdits);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Chỉnh sửa phản tư'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Áp lực đã chỉnh'),
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Áp lực đã chỉnh'), findsOneWidget);

    final notRight = find.text('Chưa hợp ✕');
    await tester.ensureVisible(notRight);
    await tester.pump();
    await tester.tap(notRight);
    await tester.pump();
    expect(
      find.text('Không sao. Bạn có thể bỏ qua các gợi ý này.'),
      findsOneWidget,
    );

    final dismissSuggestions = find.text('Bỏ qua gợi ý');
    await tester.ensureVisible(dismissSuggestions);
    await tester.pump();
    await tester.tap(dismissSuggestions);
    await tester.pump();

    expect(find.text('Bắt đầu bài tập này'), findsNothing);
    expect(find.text('Lưu làm Micro-Goal của tôi'), findsNothing);
    expect(find.text('Xem trong Lịch & Nhật ký →'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở phản tư'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.scrollUntilVisible(
      find.text('Áp lực đã chỉnh'),
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Áp lực đã chỉnh'), findsOneWidget);
    expect(find.text('Bắt đầu bài tập này'), findsNothing);
    expect(find.text('Lưu làm Micro-Goal của tôi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Practice session records optional post-exercise feedback', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = createTestState();
    const config = PracticeSessionConfig(
      id: 'feedback-test',
      title: 'Bài thực hành kiểm thử',
      purpose: 'Dừng lại và quan sát.',
      durationLabel: '1 phút · 1 bước',
      accent: Colors.orange,
      kind: PracticeKind.steps,
      prompts: [
        PracticePrompt(title: 'Một bước', body: 'Thử dừng lại một chút.'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      PracticeSessionSheet(state: state, config: config),
                ),
                child: const Text('Mở bài kiểm thử'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở bài kiểm thử'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành bài tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-in lại cảm xúc'));
    await tester.pumpAndSettle();

    expect(find.text('PHẢN HỒI TÙY CHỌN'), findsOneWidget);
    final usefulnessRating = find.descendant(
      of: find.byKey(const ValueKey('exercise-usefulness')),
      matching: find.text('4'),
    );
    await tester.ensureVisible(usefulnessRating);
    await tester.pumpAndSettle();
    await tester.tap(usefulnessRating);
    final easeRating = find.descendant(
      of: find.byKey(const ValueKey('exercise-ease')),
      matching: find.text('5'),
    );
    await tester.ensureVisible(easeRating);
    await tester.pumpAndSettle();
    await tester.tap(easeRating);
    final repeatYes = find.descendant(
      of: find.byKey(const ValueKey('exercise-repeat')),
      matching: find.text('Có'),
    );
    await tester.ensureVisible(repeatYes);
    await tester.pumpAndSettle();
    await tester.tap(repeatYes);
    await tester.ensureVisible(find.text('Lưu cảm xúc sau bài tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu cảm xúc sau bài tập'));
    await tester.pumpAndSettle();

    final savedEntry = state.entries.firstWhere(
      (entry) => entry.exerciseId == 'feedback-test',
    );
    expect(savedEntry.usefulnessRating, 4);
    expect(savedEntry.easeRating, 5);
    expect(savedEntry.repeatPreference, 'yes');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressView(state: state, onOpenCheckin: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hữu ích 4/5'), findsOneWidget);
    expect(find.text('Dễ thực hiện 5/5'), findsOneWidget);
    expect(find.text('Muốn dùng lại'), findsOneWidget);
  });

  testWidgets('Journal reopens edited reflection for its entry', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = createTestState();
    final entry = JournalEntry(
      id: 'reflection-journal-test',
      timestamp: DateTime.now(),
      emotionKey: 'stressed',
      intensity: 4,
      situation: 'Góp ý trong buổi họp',
      thought: 'Mình chưa làm đủ tốt',
    );
    state.addEntry(entry);
    state.cacheAIReflection(
      entry.id,
      AIReflection.forEmotion(
        emotionKey: entry.emotionKey,
        intensity: entry.intensity,
        situation: entry.situation,
        thought: entry.thought,
      ).copyWith(
        possibleEmotions: const ['Áp lực đã chỉnh'],
        userFeedback: 'needs_edit',
        recommendationsDismissed: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JournalView(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    final reopenReflection = find.text('Xem phản tư');
    await tester.ensureVisible(reopenReflection);
    await tester.pumpAndSettle();
    await tester.tap(reopenReflection);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Áp lực đã chỉnh'), findsOneWidget);
    expect(find.text('Bắt đầu bài tập này'), findsNothing);
    expect(find.text('Lưu làm Micro-Goal của tôi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoginView renders Google and Apple sign in buttons', (
    WidgetTester tester,
  ) async {
    final state = MindraState()..clearAllData();
    await tester.pumpWidget(
      ChangeNotifierProvider<MindraState>.value(
        value: state,
        child: const MaterialApp(
          home: LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('btn-google-sign-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn-apple-sign-in')), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    expect(find.text('Tiếp tục với Apple'), findsOneWidget);

    // Switch to register mode
    await tester.tap(find.byKey(const ValueKey('toggle-auth-mode')));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký bằng Google'), findsOneWidget);
    expect(find.text('Đăng ký bằng Apple'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsWidgets);
  });
}

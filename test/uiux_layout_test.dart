import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mindra/main.dart';
import 'package:mindra/core/theme/theme.dart';
import 'package:mindra/screens/checkin_view.dart';
import 'package:mindra/screens/journal_entry_editor.dart';
import 'package:mindra/screens/password_recovery_view.dart';
import 'package:mindra/screens/login_view.dart';
import 'package:mindra/screens/onboarding_view.dart';
import 'package:mindra/screens/settings_view.dart';
import 'package:mindra/screens/practice_session.dart';
import 'package:mindra/screens/pause_mode_sheet.dart';
import 'package:mindra/screens/ai_reflection_view.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/state/mindra_state.dart';
import 'package:provider/provider.dart';

import 'helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in FontWeight.values.sublist(1, 8)) {
      for (final style in FontStyle.values) {
        GoogleFonts.plusJakartaSans(fontWeight: weight, fontStyle: style);
      }
    }
    await GoogleFonts.pendingFonts();
    for (final entry in {
      'Roboto': 'assets/fonts/PlusJakartaSans-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/cupertino_icons/CupertinoIcons':
          'packages/cupertino_icons/assets/CupertinoIcons.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  final cases = [
    'home',
    'journal',
    'garden',
    'progress',
    'practice',
    'checkin',
    'settings',
    'login',
    'onboarding',
    'pause',
    'reflection',
    'session',
    'full-checkin',
    'register',
    'onboarding-goals',
    'onboarding-safety',
    'session-complete',
    'session-after',
    'journal-editor',
    'password-recovery',
  ];
  for (final compact in [false, true]) {
    for (final name in cases) {
      testWidgets('UI layout $name ${compact ? '320-text200' : '390-text100'}', (
        tester,
      ) async {
        tester.view.physicalSize = compact
            ? const Size(320, 568)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = compact ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final state = MindraState(initialEntries: TestData.getInitialEntries())
          ..setLowStimulationMode(true)
          ..setAiConsent(true);
        addTearDown(state.dispose);
        final entry = state.entries.first;
        state.cacheAIReflection(
          entry.id,
          AIReflection.forEmotion(
            emotionKey: entry.emotionKey,
            intensity: entry.intensity,
          ),
        );
        Widget screen;
        switch (name) {
          case 'home':
            screen = MindraApp(state: state);
          case 'journal':
            state.openJournal();
            screen = MindraApp(state: state);
          case 'garden':
            state.openGarden();
            screen = MindraApp(state: state);
          case 'progress':
            state.setTab(3);
            screen = MindraApp(state: state);
          case 'practice':
            state.setTab(3);
            screen = MindraApp(state: state);
          case 'checkin':
          case 'full-checkin':
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: CheckinView(state: state, onOpenJournal: () {}),
              ),
            );
          case 'settings':
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: SettingsView(state: state)),
            );
          case 'login':
          case 'register':
            screen = ChangeNotifierProvider.value(
              value: state,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                debugShowCheckedModeBanner: false,
                home: LoginView(),
              ),
            );
          case 'onboarding':
          case 'onboarding-goals':
          case 'onboarding-safety':
            screen = ChangeNotifierProvider.value(
              value: state,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                debugShowCheckedModeBanner: false,
                home: OnboardingView(),
              ),
            );
          case 'pause':
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: PauseModeSheet(
                  state: state,
                  onClose: () {},
                  onOpenFullCheckin: () {},
                  onOpenPractice: () {},
                ),
              ),
            );
          case 'reflection':
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: AIReflectionView(
                entry: entry,
                state: state,
                onOpenJournal: () {},
              ),
            );
          case 'journal-editor':
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: JournalEntryEditor(
                  state: state,
                  date: DateTime.now(),
                  entry: entry,
                ),
              ),
            );
          case 'password-recovery':
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              home: const PasswordRecoveryView(),
            );
          default:
            screen = MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: PracticeSessionSheet(
                  state: state,
                  config: const PracticeSessionConfig(
                    id: 'grounding',
                    title: 'Neo về hiện tại (5-4-3-2-1)',
                    purpose: 'Dùng năm giác quan để trở lại khoảnh khắc này, từng bước một.',
                    durationLabel: '2 phút · 5 bước',
                    accent: Colors.orange,
                    kind: PracticeKind.steps,
                    prompts: [
                      PracticePrompt(
                        title: 'Nhìn 5 thứ',
                        body: 'Tìm năm đồ vật quanh bạn.',
                      ),
                    ],
                  ),
                ),
              ),
            );
        }
        final errors = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details.toString());
        };
        final key = GlobalKey();
        try {
          await tester.pumpWidget(RepaintBoundary(key: key, child: screen));
          await tester.pump(const Duration(seconds: 1));
          if (name == 'practice') {
            await tester.tap(find.text('Thực hành'));
            await tester.pump(const Duration(seconds: 1));
          }
          Future<void> tapLabel(String text) async {
            await tester.ensureVisible(find.text(text));
            await tester.tap(find.text(text));
            await tester.pump(const Duration(milliseconds: 500));
          }

          if (name == 'full-checkin') {
            state.selectEmotion('happy');
            await tester.pump();
            await tapLabel('Đầy đủ');
          }
          if (name == 'register') {
            await tester.tap(find.byKey(const ValueKey('toggle-auth-mode')));
            await tester.pump(const Duration(milliseconds: 500));
          }
          if (name.startsWith('onboarding-')) {
            await tapLabel('Bắt đầu');
            if (name == 'onboarding-safety') await tapLabel('Tiếp tục');
          }
          if (name == 'session-complete' || name == 'session-after') {
            await tapLabel('Bắt đầu');
            await tapLabel('Hoàn thành bài tập');
            if (name == 'session-after') await tapLabel('Check-in lại cảm xúc');
          }
          if (const bool.fromEnvironment('CAPTURE_UI')) {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final img = await boundary.toImage(pixelRatio: 1);
              final bytes = await img.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('/private/tmp/moodi-uiux-fixed');
              await dir.create(recursive: true);
              await File('${dir.path}/$name${compact ? '-large-text' : ''}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              img.dispose();
            });
          }
          expect(
            errors,
            isEmpty,
            reason:
                '$name ${compact ? '320@2x' : '390@1x'}: ${errors.join(' | ')}',
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 30));
        } finally {
          FlutterError.onError = original;
        }
      });
    }
  }
}

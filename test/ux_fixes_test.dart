import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/theme/colors.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/state/mindra_state.dart';

import 'helpers/fake_shared_garden_repository.dart';

class RecordingJournal extends JournalRepository {
  final saved = <JournalEntry>[];
  @override
  Future<List<JournalEntry>> fetchEntries({String? userId}) async =>
      throw StateError('offline');
  @override
  Future<void> saveEntry(JournalEntry entry, {String? userId}) async =>
      saved.add(entry);
}

JournalEntry todayEntry() => JournalEntry(
  id: 'e1',
  timestamp: DateTime.now(),
  emotionKey: 'anxious',
  intensity: 4,
  thought: 'Mình sẽ trượt mất',
  response: 'Lướt điện thoại',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('completeExercise', () {
    test('keeps journal content and records practice separately', () async {
      final journal = RecordingJournal();
      final state = MindraState(
        initialEntries: [todayEntry()],
        authRepository: GardenTestAuth(),
        journalRepository: journal,
      );
      addTearDown(state.dispose);

      expect(
        state.completeExercise(exerciseId: 'grounding', note: 'Thấy nhẹ hơn'),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);

      final entry = state.entryById('e1')!;
      expect(entry.thought, 'Mình sẽ trượt mất');
      expect(entry.response, 'Lướt điện thoại');
      expect(entry.exerciseDone, isFalse);
      expect(journal.saved, isEmpty);
      expect(state.practiceRecords.single.note, 'Thấy nhẹ hơn');
      expect(state.practiceRecords.single.sourceEntryId, 'e1');
    });

    test('does not invent a check-in when no emotion was chosen', () {
      final state = MindraState(
        initialEntries: [
          JournalEntry(
            id: 'old',
            timestamp: DateTime.now().subtract(const Duration(days: 3)),
            emotionKey: 'sad',
            intensity: 2,
          ),
        ],
        authRepository: GardenTestAuth(),
        journalRepository: RecordingJournal(),
      );
      addTearDown(state.dispose);

      expect(state.completeExercise(exerciseId: 'grounding'), isTrue);
      expect(state.practiceRecords.single.beforeEmotionKey, isNull);
      expect(state.practiceRecords.single.afterEmotionKey, isNull);
      expect(state.entries, hasLength(1));
    });

    test('uses the after-exercise emotion the user picked', () {
      final state = MindraState(
        initialEntries: [
          JournalEntry(
            id: 'old',
            timestamp: DateTime.now().subtract(const Duration(days: 3)),
            emotionKey: 'sad',
            intensity: 2,
          ),
        ],
        authRepository: GardenTestAuth(),
        journalRepository: RecordingJournal(),
      );
      addTearDown(state.dispose);

      expect(
        state.completeExercise(
          exerciseId: 'grounding',
          afterEmotionKey: 'calm',
          afterIntensity: 2,
        ),
        isTrue,
      );
      expect(state.entries.single.emotionKey, 'sad');
      expect(state.practiceRecords.single.afterEmotionKey, 'calm');
      expect(state.practiceRecords.single.afterIntensity, 2);
    });
  });

  test('device preferences survive a restart', () async {
    final first = MindraState(
      initialEntries: [todayEntry()],
      authRepository: GardenTestAuth(),
      journalRepository: RecordingJournal(),
    );
    first
      ..resetOnboarding()
      ..completeOnboarding()
      ..setLowStimulationMode(true)
      ..setGardenVisible(false)
      ..toggleGoal('Phản hồi bình tĩnh hơn');
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final second = MindraState(
      authRepository: GardenTestAuth(),
      journalRepository: RecordingJournal(),
      isAuthenticated: false,
    );
    addTearDown(second.dispose);
    final loading = second.loadLocalPreferences();
    expect(second.startingUp, isTrue);
    await loading;

    expect(second.startingUp, isFalse);
    expect(second.onboardingCompleted, isTrue);
    expect(second.lowStimulationMode, isTrue);
    expect(second.gardenVisible, isFalse);
    expect(second.userGoals, contains('Phản hồi bình tĩnh hơn'));
  });

  test('reflection keeps its source so the screen can label AI output', () {
    final ai = AIReflection.fromJson({'source': 'ai', 'possibleEmotions': []});
    expect(ai.source, 'ai');
    expect(ai.copyWith(userFeedback: 'accurate').source, 'ai');
    expect(AIReflection.fromJson({}).source, 'template');
    expect(
      AIReflection.forEmotion(emotionKey: 'sad', intensity: 3).source,
      'local',
    );
  });

  test('emotion cards pick the readable text color', () {
    // Chỉ nền xanh đậm cần chữ trắng; hồng/cam/xám/tím nhạt dùng chữ đậm.
    expect(AppColors.prefersLightText(AppColors.blue), isTrue);
    for (final tone in [
      AppColors.pink,
      AppColors.orange,
      AppColors.gray,
      AppColors.lavender,
      AppColors.yellow,
      AppColors.mint,
    ]) {
      expect(AppColors.prefersLightText(tone), isFalse);
    }
    expect(AppColors.prefersLightText(Colors.black), isTrue);
  });
}

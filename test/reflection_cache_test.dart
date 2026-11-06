import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/models/ai_reflection.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/repositories/reflection_repository.dart';
import 'package:mindra/state/mindra_state.dart';

import 'helpers/fake_shared_garden_repository.dart';

class OfflineJournal extends JournalRepository {
  @override
  Future<List<JournalEntry>> fetchEntries({String? userId}) async =>
      throw StateError('offline');
  @override
  Future<void> saveEntry(JournalEntry entry, {String? userId}) async {}
}

class CountingReflection extends ReflectionRepository {
  final calls = <String?>[];
  final pending = <Completer<AIReflection>>[];
  final feedback = <String>[];

  @override
  Future<void> saveReflectionFeedback({
    required String reflectionId,
    required String feedback,
    required bool helpful,
    Map<String, dynamic>? edits,
  }) async {
    this.feedback.add(reflectionId);
  }

  @override
  Future<AIReflection> generateReflection({
    required String emotionKey,
    required int intensity,
    String? situation,
    String? thought,
    String? entryId,
  }) {
    calls.add(situation);
    final completer = Completer<AIReflection>();
    pending.add(completer);
    return completer.future;
  }
}

AIReflection reflectionFor(String? situation) => AIReflection.forEmotion(
  emotionKey: 'sad',
  intensity: 3,
  situation: situation,
);

JournalEntry sadEntry({String situation = 'Bị điểm kém'}) => JournalEntry(
  id: 'e1',
  timestamp: DateTime(2026, 11, 6),
  emotionKey: 'sad',
  intensity: 3,
  situation: situation,
);

void main() {
  MindraState buildState(CountingReflection reflections) => MindraState(
    initialEntries: [sadEntry()],
    authRepository: GardenTestAuth(),
    journalRepository: OfflineJournal(),
    reflectionRepository: reflections,
  )..setAiConsent(true);

  test('opening the reflection twice sends a single request', () async {
    final reflections = CountingReflection();
    final state = buildState(reflections);
    addTearDown(state.dispose);

    final first = state.fetchOrGenerateAIReflection(sadEntry());
    final second = state.fetchOrGenerateAIReflection(sadEntry());
    expect(reflections.calls, hasLength(1));

    reflections.pending.single.complete(reflectionFor('Bị điểm kém'));
    expect(await first, same(await second));
    expect(state.reflectionForEntry('e1'), isNotNull);
  });

  test('editing the entry drops the cached reflection', () async {
    final reflections = CountingReflection();
    final state = buildState(reflections);
    addTearDown(state.dispose);

    final request = state.fetchOrGenerateAIReflection(sadEntry());
    reflections.pending.single.complete(reflectionFor('Bị điểm kém'));
    await request;
    expect(state.reflectionForEntry('e1'), isNotNull);

    final edited = sadEntry(situation: 'Mình muốn chết');
    state.updateEntry(edited);
    expect(state.reflectionForEntry('e1'), isNull);

    final regenerated = state.fetchOrGenerateAIReflection(edited);
    await state.flushLocalData();
    await Future<void>.delayed(Duration.zero);
    expect(reflections.calls, ['Bị điểm kém', 'Mình muốn chết']);
    reflections.pending.last.complete(reflectionFor(edited.situation));
    await regenerated;
  });

  test('a request for old content cannot overwrite the edited entry', () async {
    final reflections = CountingReflection();
    final state = buildState(reflections);
    addTearDown(state.dispose);

    final stale = state.fetchOrGenerateAIReflection(sadEntry());
    state.updateEntry(sadEntry(situation: 'Mình muốn chết'));
    reflections.pending.single.complete(reflectionFor('Bị điểm kém'));

    await expectLater(stale, throwsStateError);
    expect(state.reflectionForEntry('e1'), isNull);
  });

  test('metadata-only edits keep the cached reflection', () async {
    final reflections = CountingReflection();
    final state = buildState(reflections);
    addTearDown(state.dispose);

    final request = state.fetchOrGenerateAIReflection(sadEntry());
    reflections.pending.single.complete(reflectionFor('Bị điểm kém'));
    await request;

    state.updateEntry(sadEntry().copyWith(exerciseDone: true));
    expect(state.reflectionForEntry('e1'), isNotNull);
  });

  test('AI is opt-in at the request boundary', () async {
    final reflections = CountingReflection();
    final state = buildState(reflections)..setAiConsent(false);
    addTearDown(state.dispose);
    await expectLater(
      state.fetchOrGenerateAIReflection(sadEntry()),
      throwsStateError,
    );
    expect(reflections.calls, isEmpty);
  });

  test(
    'a late generated result preserves edits and attaches its server id',
    () async {
      final reflections = CountingReflection();
      final state = buildState(reflections);
      addTearDown(state.dispose);
      final request = state.fetchOrGenerateAIReflection(sadEntry());
      state.updateAIReflection(
        'e1',
        reflectionFor('local').copyWith(
          balancedThought: 'Lời tôi đã sửa',
          userFeedback: 'needs_edit',
        ),
      );
      reflections.pending.single.complete(
        AIReflection.fromJson({
          ...reflectionFor('server').toJson(),
          'id': 'server-reflection',
        }),
      );
      final result = await request;
      expect(result.balancedThought, 'Lời tôi đã sửa');
      expect(state.reflectionForEntry('e1')!.id, 'server-reflection');
      expect(reflections.feedback, ['server-reflection']);
    },
  );
}

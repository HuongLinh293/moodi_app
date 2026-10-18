import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/state/mindra_state.dart';

import 'helpers/fake_shared_garden_repository.dart';

class ControlledJournal extends JournalRepository {
  final writes = <Completer<void>>[];
  final ids = <String>[];
  @override
  Future<List<JournalEntry>> fetchEntries({String? userId}) async =>
      throw StateError('offline');
  @override
  Future<void> saveEntry(JournalEntry entry, {String? userId}) {
    ids.add(entry.id);
    final completer = Completer<void>();
    writes.add(completer);
    return completer.future;
  }

  @override
  Future<void> deleteEntry(String entryId, {String? userId}) async {}
}

JournalEntry entry(String id) => JournalEntry(
  id: id,
  timestamp: DateTime.now(),
  emotionKey: 'sad',
  intensity: 3,
);

void main() {
  test(
    'Failed write stays visible and retries same id without duplication',
    () async {
      final repo = ControlledJournal();
      final state = MindraState(
        initialEntries: [entry('seed')],
        authRepository: GardenTestAuth(),
        journalRepository: repo,
      );
      addTearDown(state.dispose);
      state.addEntry(entry('new'));
      expect(state.entrySyncStatus('new'), EntrySyncStatus.pending);
      repo.writes[0].completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(state.entrySyncStatus('new'), EntrySyncStatus.failed);
      expect(state.entryById('new'), isNotNull);
      state.retryEntrySync();
      expect(state.entrySyncStatus('new'), EntrySyncStatus.pending);
      repo.writes[1].complete();
      await Future<void>.delayed(Duration.zero);
      expect(state.entrySyncStatus('new'), EntrySyncStatus.synced);
      expect(repo.ids, ['new', 'new']);
      expect(state.entries.where((e) => e.id == 'new'), hasLength(1));
    },
  );

  test('Old acknowledgement cannot overwrite newer failed edit', () async {
    final repo = ControlledJournal();
    final state = MindraState(
      initialEntries: [entry('seed')],
      authRepository: GardenTestAuth(),
      journalRepository: repo,
    );
    addTearDown(state.dispose);
    state.addEntry(entry('new'));
    state.updateEntry(entry('new').copyWith(thought: 'new draft'));
    repo.writes[1].completeError(StateError('denied'));
    await Future<void>.delayed(Duration.zero);
    repo.writes[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(state.entrySyncStatus('new'), EntrySyncStatus.failed);
    expect(state.entryById('new')!.thought, 'new draft');
  });

  test('Failed refresh does not erase existing or unsynced entries', () async {
    final repo = ControlledJournal();
    final state = MindraState(
      initialEntries: [entry('seed')],
      authRepository: GardenTestAuth(),
      journalRepository: repo,
    );
    addTearDown(state.dispose);
    state.addEntry(entry('new'));
    await state.syncFromFirestore();
    expect(state.entryById('seed'), isNotNull);
    expect(state.entryById('new'), isNotNull);
    expect(state.entrySyncStatus('new'), EntrySyncStatus.pending);
    repo.writes.single.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('Session-only entry is not sent to an unowned collection', () {
    final repo = ControlledJournal();
    final auth = GardenTestAuth()..uid = null;
    final state = MindraState(
      initialEntries: [entry('seed')],
      authRepository: auth,
      journalRepository: repo,
    );
    addTearDown(state.dispose);
    state.addEntry(entry('new'));
    expect(state.entrySyncStatus('new'), EntrySyncStatus.sessionOnly);
    expect(repo.writes, isEmpty);
  });
}

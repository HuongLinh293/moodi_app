import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/models/practice_record.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/repositories/practice_repository.dart';
import 'package:mindra/state/mindra_state.dart';

import 'helpers/fake_shared_garden_repository.dart';

class FlakyJournal extends JournalRepository {
  bool offline = true;
  final log = <String>[];
  @override
  Future<List<JournalEntry>> fetchEntries({String? userId}) async =>
      throw StateError('offline');
  @override
  Future<void> saveEntry(JournalEntry entry, {String? userId}) async {
    if (offline) throw StateError('offline');
    log.add('entry:${entry.id}');
  }
}

class LoggingPractice extends PracticeRepository {
  LoggingPractice(this.log);
  final List<String> log;
  @override
  Future<void> save(PracticeRecord record) async =>
      log.add('practice:${record.sourceEntryId}');
  @override
  Future<List<PracticeRecord>> fetch() async => [];
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('practice uploads its unsynced check-in first', () async {
    final journal = FlakyJournal();
    final state = MindraState(
      authRepository: GardenTestAuth(),
      journalRepository: journal,
      practiceRepository: LoggingPractice(journal.log),
    );
    addTearDown(state.dispose);
    state.addEntry(
      JournalEntry(
        id: 'e1',
        timestamp: DateTime.now(),
        emotionKey: 'sad',
        intensity: 3,
      ),
    );
    await state.flushLocalData();
    await settle();
    expect(state.entrySyncStatus('e1'), EntrySyncStatus.failed);

    journal.offline = false;
    state.recordPractice(exerciseId: 'breathing', sourceEntryId: 'e1');
    await state.flushLocalData();
    await settle();
    expect(journal.log, ['entry:e1', 'practice:e1']);
  });
}

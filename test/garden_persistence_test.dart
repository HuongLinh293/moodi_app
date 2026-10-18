import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/models/garden_moment.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/repositories/garden_repository.dart';
import 'package:mindra/repositories/journal_repository.dart';
import 'package:mindra/state/mindra_state.dart';
import 'helpers/fake_shared_garden_repository.dart';

class RecordingGarden extends GardenRepository {
  bool fail = false;
  final saved = <String>[];
  final deleted = <String>[];
  @override
  Future<void> saveMoment(GardenMoment moment, {String? userId}) async {
    if (fail) throw StateError('offline');
    saved.add('$userId/${moment.id}');
  }
  @override
  Future<void> deleteMoment(String momentId, {required String userId}) async {
    if (fail) throw StateError('offline');
    deleted.add('$userId/$momentId');
  }
}
class RecordingJournal extends JournalRepository {
  bool fail = false;
  final deleted = <String>[];
  @override
  Future<void> deleteEntry(String entryId, {String? userId}) async {
    if (fail) throw StateError('offline');
    deleted.add('$userId/$entryId');
  }
}
void main() {
  test('Personal flower is retained on failed delete; successful delete is persisted', () async {
    final garden = RecordingGarden();
    final journal = RecordingJournal();
    final state = MindraState(initialEntries: [JournalEntry(id: 'entry', timestamp: DateTime.now(), emotionKey: 'calm', intensity: 3)],
      authRepository: GardenTestAuth(), gardenRepository: garden, journalRepository: journal);
    addTearDown(state.dispose);
    garden.fail = true;
    await expectLater(state.removeMoment('garden-entry'), throwsStateError);
    expect(state.isPlanted('entry'), isTrue);
    garden.fail = false;
    await state.removeMoment('garden-entry');
    expect(garden.deleted, ['user_1/garden-entry']);
    expect(state.isPlanted('entry'), isFalse);
    garden.fail = true;
    await expectLater(state.plantMoment('entry'), throwsStateError);
    expect(state.isPlanted('entry'), isFalse);
    garden.fail = false;
    await state.plantMoment('entry');
    expect(garden.saved, ['user_1/garden-entry']);
    journal.fail = true;
    await expectLater(state.removeEntry('entry'), throwsStateError);
    expect(state.isPlanted('entry'), isTrue);
    expect(state.entryById('entry'), isNotNull);
    journal.fail = false;
    await state.removeEntry('entry');
    expect(journal.deleted, ['user_1/entry']);
    expect(state.entryById('entry'), isNull);
    expect(state.isPlanted('entry'), isFalse);
  });
}

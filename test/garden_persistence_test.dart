import 'dart:async';

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

  @override
  Future<void> deleteAllMoments({required String userId}) async {
    if (fail) throw StateError('offline');
    deleted.add('$userId/*');
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

  @override
  Future<void> deleteAllEntries({required String userId}) async {
    if (fail) throw StateError('offline');
    deleted.add('$userId/*');
  }
}

class OrderedJournal extends RecordingJournal {
  final saveGate = Completer<void>();
  @override
  Future<void> saveEntry(JournalEntry entry, {String? userId}) async {
    await saveGate.future;
    deleted.add('save/${entry.id}');
  }
}

void main() {
  test('Personal flower is retained on failed delete; successful delete is persisted', () async {
    final garden = RecordingGarden();
    final journal = RecordingJournal();
    final state = MindraState(
      initialEntries: [
        JournalEntry(
          id: 'entry',
          timestamp: DateTime.now(),
          emotionKey: 'calm',
          intensity: 3,
        ),
      ],
      authRepository: GardenTestAuth(),
      gardenRepository: garden,
      journalRepository: journal,
    );
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
  test(
    'Delete all removes account data and keeps local data on failure',
    () async {
      final garden = RecordingGarden();
      final journal = RecordingJournal();
      final state = MindraState(
        initialEntries: [
          JournalEntry(
            id: 'entry',
            timestamp: DateTime.now(),
            emotionKey: 'calm',
            intensity: 3,
          ),
        ],
        authRepository: GardenTestAuth(),
        gardenRepository: garden,
        journalRepository: journal,
      );
      addTearDown(state.dispose);
      journal.fail = true;
      await expectLater(state.deleteAllUserData(), throwsStateError);
      expect(state.entries, hasLength(1));
      journal.fail = false;
      await state.deleteAllUserData();
      expect(journal.deleted, ['user_1/*']);
      expect(garden.deleted, ['user_1/*']);
      expect(state.entries, isEmpty);
      expect(state.gardenMoments, isEmpty);
    },
  );
  test(
    'Delete all waits for in-flight saves so entries are not recreated',
    () async {
      final journal = OrderedJournal();
      final state = MindraState(
        initialEntries: [
          JournalEntry(
            id: 'old',
            timestamp: DateTime.now(),
            emotionKey: 'calm',
            intensity: 3,
          ),
        ],
        authRepository: GardenTestAuth(),
        gardenRepository: RecordingGarden(),
        journalRepository: journal,
      );
      addTearDown(state.dispose);
      state.addEntry(
        JournalEntry(
          id: 'new',
          timestamp: DateTime.now(),
          emotionKey: 'sad',
          intensity: 2,
        ),
      );
      final deleting = state.deleteAllUserData();
      await Future<void>.delayed(Duration.zero);
      expect(journal.deleted, isEmpty);
      journal.saveGate.complete();
      await deleting;
      expect(journal.deleted, ['save/new', 'user_1/*']);
    },
  );

  test('Deleting an entry waits for its in-flight save', () async {
    final journal = OrderedJournal();
    final state = MindraState(
      authRepository: GardenTestAuth(),
      gardenRepository: RecordingGarden(),
      journalRepository: journal,
    );
    addTearDown(state.dispose);
    state.addEntry(
      JournalEntry(
        id: 'new',
        timestamp: DateTime.now(),
        emotionKey: 'sad',
        intensity: 2,
      ),
    );
    final removing = state.removeEntry('new');
    await Future<void>.delayed(Duration.zero);
    expect(journal.deleted, isEmpty);
    journal.saveGate.complete();
    await removing;
    expect(journal.deleted, ['save/new', 'user_1/new']);
    expect(state.entryById('new'), isNull);
  });
}

import 'dart:async';

import 'package:mindra/models/shared_garden.dart';
import 'package:mindra/repositories/auth_repository.dart';
import 'package:mindra/repositories/shared_garden_repository.dart';

class GardenTestAuth extends AuthRepository {
  String? uid = 'user_1';
  @override
  String? get currentUserId => uid;
}

class FakeSharedGardenRepository extends SharedGardenRepository {
  final membership = StreamController<SharedGarden?>.broadcast(sync: true);
  final streams = <String, StreamController<List<SharedMoment>>>{};
  SharedGarden? garden;
  bool fail = false;
  final items = <SharedMoment>[];
  int leaves = 0;
  void check() {
    if (fail) throw StateError('Lưu thất bại');
  }

  @override
  Stream<SharedGarden?> watchUserGarden(String userId) => membership.stream;
  @override
  Stream<List<SharedMoment>> watchMoments(String gardenId) => streams
      .putIfAbsent(
        gardenId,
        () => StreamController<List<SharedMoment>>.broadcast(sync: true),
      )
      .stream;
  @override
  Future<SharedGarden> createGarden({
    required String userId,
    required String userName,
    String? gardenName,
  }) async {
    check();
    garden = SharedGarden(
      id: 'garden-1',
      code: 'MD-${'A' * 32}',
      name: gardenName ?? 'Vườn sẻ chia',
      members: [userId],
      memberNames: {userId: 'Linh'},
      createdAt: DateTime(2026, 10),
    );
    membership.add(garden);
    return garden!;
  }

  @override
  Future<SharedGarden?> joinGardenByCode({
    required String code,
    required String userId,
    required String userName,
  }) async {
    check();
    return garden;
  }

  @override
  Future<SharedMoment> plantEntry(
    String gardenId,
    String entryId, {
    bool includeCaption = false,
  }) async {
    check();
    final moment = SharedMoment(
      id: 'user_1_$entryId',
      gardenId: gardenId,
      authorId: 'user_1',
      authorName: 'Linh',
      emotionKey: 'calm',
      intensity: 3,
      caption: includeCaption ? 'Bình yên' : '',
      bedIndex: items.length ~/ 20,
      slotIndex: items.length % 20,
      monthKey: '2026-10',
      plantedAt: DateTime(2026, 10),
    );
    items.add(moment);
    streams[gardenId]?.add(List.of(items));
    return moment;
  }

  final removed = <String>[];
  @override
  Future<void> removeMoment(String gardenId, String momentId) async {
    check();
    removed.add(momentId);
    items.removeWhere((m) => m.id == momentId);
    streams[gardenId]?.add(List.of(items));
  }

  @override
  Future<void> removeMyMoments(String gardenId) async {
    check();
    removed.add('$gardenId/*');
    items.removeWhere((m) => m.authorId == 'user_1');
    streams[gardenId]?.add(List.of(items));
  }

  @override
  Future<void> leaveGarden(String gardenId) async {
    check();
    leaves++;
    membership.add(null);
  }

  @override
  void dispose() {
    membership.close();
    for (final stream in streams.values) {
      stream.close();
    }
  }
}

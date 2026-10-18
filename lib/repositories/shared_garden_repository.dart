import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_garden.dart';

class SharedGardenRepository {
  final FirebaseFirestore? firestore;
  SharedGardenRepository({this.firestore});
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _gardens => _db.collection('shared_gardens');
  CollectionReference<Map<String, dynamic>> get _invites => _db.collection('shared_garden_invites');
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Hãy đăng nhập để sử dụng vườn chung.');
    return uid;
  }
  String _code() {
    final random = Random.secure();
    return 'MD-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
  }
  String _name(String name) => name.trim().isEmpty ? 'Bạn đồng hành' : name.trim().substring(0, min(name.trim().length, 80));

  Future<SharedGarden> createGarden({required String userId, required String userName, String? gardenName}) async {
    if (_uid != userId) throw StateError('Phiên đăng nhập đã thay đổi.');
    final existing = await _gardens.where('members', arrayContains: userId).limit(1).get(const GetOptions(source: Source.server));
    if (existing.docs.isNotEmpty) return SharedGarden.fromFirestore(existing.docs.first.data(), existing.docs.first.id);
    final ref = _gardens.doc();
    final garden = SharedGarden(id: ref.id, code: _code(), name: gardenName ?? 'Vườn sẻ chia', members: [userId], memberNames: {userId: _name(userName)}, createdAt: DateTime.now());
    final batch = _db.batch();
    batch.set(ref, {...garden.toFirestore(), 'nextSlot': 0, 'lastPlantId': '', 'joinProof': ''});
    batch.set(_invites.doc(garden.code), {'gardenId': ref.id});
    await batch.commit();
    return garden;
  }

  Future<SharedGarden?> joinGardenByCode({required String code, required String userId, required String userName}) async {
    if (_uid != userId) throw StateError('Phiên đăng nhập đã thay đổi.');
    final clean = code.trim().toUpperCase();
    if (!RegExp(r'^MD-[A-F0-9]{32}$').hasMatch(clean)) throw StateError('Mã mời đã cũ hoặc không hợp lệ. Hãy nhờ bạn gửi mã mới.');
    final invitation = await _invites.doc(clean).get(const GetOptions(source: Source.server));
    if (!invitation.exists) throw StateError('Không tìm thấy mã mời hoặc mã đã hết hiệu lực.');
    final ref = _gardens.doc(invitation.data()!['gardenId'] as String);
    final existing = await _gardens.where('members', arrayContains: userId).limit(1).get(const GetOptions(source: Source.server));
    if (existing.docs.isNotEmpty) {
      if (existing.docs.first.id != ref.id) throw StateError('Hãy rời vườn hiện tại trước khi vào vườn khác.');
      return SharedGarden.fromFirestore(existing.docs.first.data(), ref.id);
    }
    // Atomic transform: rules validate the invitation proof and final capacity.
    await ref.update({'members': FieldValue.arrayUnion([userId]), 'memberNames.$userId': _name(userName), 'joinProof': clean});
    final joined = await ref.get(const GetOptions(source: Source.server));
    return SharedGarden.fromFirestore(joined.data()!, ref.id);
  }

  Stream<SharedGarden?> watchUserGarden(String userId) => _gardens.where('members', arrayContains: userId).limit(1).snapshots(includeMetadataChanges: true)
      .where((snap) => !snap.metadata.hasPendingWrites)
      .map((snap) => snap.docs.isEmpty ? null : SharedGarden.fromFirestore(snap.docs.first.data(), snap.docs.first.id));
  Stream<SharedGarden?> watchGarden(String gardenId) => _gardens.doc(gardenId).snapshots(includeMetadataChanges: true)
      .where((snap) => !snap.metadata.hasPendingWrites)
      .map((snap) => snap.exists ? SharedGarden.fromFirestore(snap.data()!, snap.id) : null);
  Stream<List<SharedMoment>> watchMoments(String gardenId) => _gardens.doc(gardenId).collection('moments').orderBy('plantedAt').snapshots(includeMetadataChanges: true)
      .where((snap) => !snap.metadata.hasPendingWrites)
      .map((snap) => snap.docs.map((doc) => SharedMoment.fromFirestore(doc.data(), doc.id)).toList());

  Future<SharedMoment> plantEntry(String gardenId, String entryId) async {
    final uid = _uid;
    final ref = _gardens.doc(gardenId);
    final momentRef = ref.collection('moments').doc('${uid}_$entryId');
    // Old gardens have no counter. Preserve their existing placements.
    final previous = await ref.get(const GetOptions(source: Source.server));
    int legacyNext = 0;
    if (previous.data()?['nextSlot'] == null) {
      final old = await ref.collection('moments').get(const GetOptions(source: Source.server));
      for (final doc in old.docs) {
        final m = SharedMoment.fromFirestore(doc.data(), doc.id);
        legacyNext = max(legacyNext, m.bedIndex * 20 + m.slotIndex + 1);
      }
    }
    return _db.runTransaction((tx) async {
      final garden = (await tx.get(ref)).data();
      if (garden == null || !(garden['members'] as List).contains(uid)) throw StateError('Bạn không còn là thành viên.');
      final old = await tx.get(momentRef);
      if (old.exists) return SharedMoment.fromFirestore(old.data()!, old.id);
      final entry = (await tx.get(_db.collection('users').doc(uid).collection('journal_entries').doc(entryId))).data();
      if (entry == null) throw StateError('Ghi chép chưa được đồng bộ. Hãy thử lại.');
      final position = (garden['nextSlot'] as num?)?.toInt() ?? legacyNext;
      final situation = (entry['situation'] as String? ?? '').trim();
      final thought = (entry['thought'] as String? ?? '').trim();
      final plantedAt = DateTime.parse(entry['timestamp'] as String);
      final moment = SharedMoment(id: momentRef.id, gardenId: gardenId, authorId: uid,
        authorName: (garden['memberNames'] as Map)[uid] as String,
        emotionKey: entry['emotionKey'] as String, intensity: (entry['intensity'] as num).toInt(),
        caption: situation.isNotEmpty ? situation : thought, bedIndex: position ~/ 20, slotIndex: position % 20,
        monthKey: '${plantedAt.year}-${plantedAt.month.toString().padLeft(2, '0')}', plantedAt: plantedAt);
      tx.set(momentRef, {...moment.toFirestore(), 'entryId': entryId});
      tx.update(ref, {'nextSlot': position + 1, 'lastPlantId': momentRef.id});
      return moment;
    });
  }

  Future<void> leaveGarden(String gardenId) async {
    final uid = _uid;
    final ref = _gardens.doc(gardenId);
    final code = _code();
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw StateError('Vườn không còn tồn tại.');
      final members = List<String>.from(data['members'] as List)..remove(uid);
      final names = Map<String, dynamic>.from(data['memberNames'] as Map)..remove(uid);
      tx.update(ref, {'members': members, 'memberNames': names, 'code': code, 'joinProof': ''});
      if ((data['code'] as String).length == 35) tx.delete(_invites.doc(data['code'] as String));
      if (members.isNotEmpty) tx.set(_invites.doc(code), {'gardenId': gardenId});
    });
  }

  Future<String> refreshInvite(String gardenId) async {
    final ref = _gardens.doc(gardenId);
    final code = _code();
    await _db.runTransaction((tx) async {
      final garden = (await tx.get(ref)).data();
      if (garden == null) throw StateError('Vườn không còn tồn tại.');
      tx.update(ref, {'code': code, 'joinProof': ''});
      if ((garden['code'] as String).length == 35) tx.delete(_invites.doc(garden['code'] as String));
      tx.set(_invites.doc(code), {'gardenId': gardenId});
    });
    return code;
  }

  Future<SharedMoment> interactMoment({required String gardenId, required String momentId, required bool isWater, required String interactorName}) async {
    final uid = _uid;
    final ref = _gardens.doc(gardenId).collection('moments').doc(momentId);
    final reaction = ref.collection('care').doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final care = (await tx.get(reaction)).data() ?? {'water': false, 'sun': false};
      if (!snap.exists) throw StateError('Khoảnh khắc không còn tồn tại.');
      final moment = SharedMoment.fromFirestore(snap.data()!, snap.id);
      final kind = isWater ? 'water' : 'sun';
      if (care[kind] == true) return moment;
      final updated = moment.copyWith(waterCount: moment.waterCount + (isWater ? 1 : 0),
        sunCount: moment.sunCount + (isWater ? 0 : 1),
        lastInteraction: isWater ? '${_name(interactorName)} vừa tưới nước 💧' : '${_name(interactorName)} vừa gửi tia nắng ấm ☀️');
      tx.set(reaction, {...care, kind: true});
      tx.update(ref, {'waterCount': updated.waterCount, 'sunCount': updated.sunCount, 'lastInteraction': updated.lastInteraction});
      return updated;
    });
  }
  void dispose() {}
}

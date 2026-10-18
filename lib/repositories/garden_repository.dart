import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/garden_moment.dart';

class GardenRepository {
  final FirebaseFirestore? firestore;

  GardenRepository({this.firestore});

  FirebaseFirestore get _instance => firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _momentsCollection(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return _instance
          .collection('users')
          .doc(userId)
          .collection('garden_moments');
    }
    return _instance.collection('garden_moments');
  }

  Future<void> saveMoment(GardenMoment moment, {String? userId}) async {
    try {
      final docRef = _momentsCollection(userId).doc(moment.id);
      await docRef.set(
        moment.toFirestore(userId: userId),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('GardenRepository: Error saving moment $e');
      rethrow;
    }
  }

  Future<void> deleteMoment(String momentId, {required String userId}) async {
    await _momentsCollection(userId).doc(momentId).delete();
  }

  Future<List<GardenMoment>> fetchMoments({String? userId}) async {
    try {
      final snapshot = await _momentsCollection(userId)
          .orderBy('plantedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => GardenMoment.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('GardenRepository: Error fetching moments $e');
      return [];
    }
  }

  Stream<List<GardenMoment>> watchMoments({String? userId}) {
    try {
      return _momentsCollection(userId)
          .orderBy('plantedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => GardenMoment.fromFirestore(doc.data(), doc.id))
                .toList(),
          );
    } catch (e) {
      debugPrint('GardenRepository: Error watching moments $e');
      return const Stream.empty();
    }
  }
}

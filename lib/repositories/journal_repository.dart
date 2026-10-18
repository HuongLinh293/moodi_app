import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/journal_entry.dart';

class JournalRepository {
  final FirebaseFirestore? firestore;

  JournalRepository({this.firestore});

  FirebaseFirestore get _instance => firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _entriesCollection(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return _instance
          .collection('users')
          .doc(userId)
          .collection('journal_entries');
    }
    return _instance.collection('journal_entries');
  }

  Future<void> saveEntry(JournalEntry entry, {String? userId}) async {
    try {
      final docRef = _entriesCollection(userId).doc(entry.id);
      await docRef.set(
        entry.toFirestore(userId: userId),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('JournalRepository: Error saving entry $e');
      rethrow;
    }
  }

  Future<List<JournalEntry>> fetchEntries({String? userId}) async {
    try {
      final snapshot = await _entriesCollection(userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('JournalRepository: Error fetching entries $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(String entryId, {String? userId}) async {
    try {
      final batch = _instance.batch();
      batch.delete(_entriesCollection(userId).doc(entryId));
      final moments = userId == null
          ? _instance.collection('garden_moments')
          : _instance
                .collection('users')
                .doc(userId)
                .collection('garden_moments');
      batch.delete(moments.doc('garden-$entryId'));
      await batch.commit();
    } catch (e) {
      debugPrint('JournalRepository: Error deleting entry $e');
      rethrow;
    }
  }

  Stream<List<JournalEntry>> watchEntries({String? userId}) {
    try {
      return _entriesCollection(userId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => JournalEntry.fromFirestore(doc.data(), doc.id))
                .toList(),
          );
    } catch (e) {
      debugPrint('JournalRepository: Error watching entries $e');
      return const Stream.empty();
    }
  }
}

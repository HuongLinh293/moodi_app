import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A per-account encrypted snapshot, including writes awaiting acknowledgement.
/// Writes are serialized by the owner so an older snapshot cannot replace a new one.
class JournalCache {
  JournalCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  final Map<String, String> _lastSnapshot = {};
  String _key(String uid) => 'moodi.journal.$uid.v1';

  Future<Map<String, dynamic>?> read(String uid) async {
    final raw = await _storage.read(key: _key(uid));
    if (raw != null) _lastSnapshot[uid] = raw;
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> write(String uid, Map<String, dynamic> snapshot) async {
    final encoded = jsonEncode(snapshot);
    if (_lastSnapshot[uid] == encoded) return;
    await _storage.write(key: _key(uid), value: encoded);
    _lastSnapshot[uid] = encoded;
  }
}

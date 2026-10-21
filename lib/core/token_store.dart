import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Phiên đã lưu: chỉ refresh token và thông tin hiển thị của user.
/// Access token sống ngắn nên chỉ giữ trong bộ nhớ.
class StoredSession {
  final String refreshToken;
  final Map<String, dynamic> user;

  const StoredSession({required this.refreshToken, required this.user});
}

abstract class TokenStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore (Android). Trên iOS dùng
/// `first_unlock_this_device`: không đồng bộ iCloud, không theo bản sao lưu
/// sang máy khác.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _key = 'moodi.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final token = data['refreshToken'];
      final user = data['user'];
      if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
        await clear();
        return null;
      }
      return StoredSession(refreshToken: token, user: user);
    } catch (e) {
      // Không có plugin (test) hoặc dữ liệu hỏng: coi như chưa đăng nhập.
      debugPrint('SecureTokenStore: read failed (${e.runtimeType})');
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'refreshToken': session.refreshToken,
          'user': session.user,
        }),
      );
    } catch (e) {
      debugPrint('SecureTokenStore: write failed (${e.runtimeType})');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('SecureTokenStore: clear failed (${e.runtimeType})');
    }
  }
}

class MemoryTokenStore implements TokenStore {
  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Kết quả đăng nhập gốc: token của nhà cung cấp kèm nonce gốc để server
/// đối chiếu với SHA-256 đã nhúng trong token.
class SocialCredential {
  final String token;
  final String rawNonce;
  final String? displayName;

  const SocialCredential({
    required this.token,
    required this.rawNonce,
    this.displayName,
  });
}

/// Bật bằng --dart-define. Nút chỉ hiện khi đã cấu hình phía app (và server
/// báo provider đang bật), để không có nút bấm vào rồi lỗi/crash.
/// - GOOGLE_IOS_CLIENT_ID: iOS client ID (cần thêm reversed client ID vào
///   CFBundleURLTypes trong ios/Runner/Info.plist).
/// - GOOGLE_SERVER_CLIENT_ID: Web client ID mà server dùng làm audience
///   (bắt buộc trên Android).
/// - APPLE_SIGN_IN=true: chỉ bật khi Runner đã có capability Sign in with Apple
///   (cần tài khoản Apple Developer trả phí).
class SocialSignIn {
  // Client ID là định danh công khai (đã có trong GoogleService-Info.plist),
  // không phải bí mật. Reversed ID tương ứng đã khai báo trong Info.plist.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '1017414745880-gg3005b3ngf3a2el8oam9dm1s3i3spf2.apps.googleusercontent.com',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const appleEnabled = bool.fromEnvironment('APPLE_SIGN_IN');

  Future<void>? _googleInit;
  String? _googleRawNonce;

  bool get googleConfigured {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS => googleIosClientId.isNotEmpty,
      TargetPlatform.android => googleServerClientId.isNotEmpty,
      _ => false,
    };
  }

  Future<bool> appleAvailable() async {
    if (!appleEnabled || kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Trả null khi người dùng huỷ.
  Future<SocialCredential?> google() async {
    // google_sign_in 7 chỉ cho initialize một lần, nên nonce cố định trong
    // suốt phiên chạy app (vẫn chặn được token bị đánh cắp dùng ở máy khác).
    _googleInit ??= () {
      _googleRawNonce = _randomNonce();
      return GoogleSignIn.instance.initialize(
        clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
        serverClientId: googleServerClientId.isEmpty
            ? null
            : googleServerClientId,
        nonce: _sha256(_googleRawNonce!),
      );
    }();
    await _googleInit;
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google không trả về ID token.');
      return SocialCredential(
        token: idToken,
        rawNonce: _googleRawNonce!,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Nonce mới cho mỗi lần đăng nhập Apple. Trả null khi người dùng huỷ.
  Future<SocialCredential?> apple() async {
    final rawNonce = _randomNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );
      final token = credential.identityToken;
      if (token == null) throw StateError('Apple không trả về identity token.');
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().join(' ').trim();
      return SocialCredential(
        token: token,
        rawNonce: rawNonce,
        displayName: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_googleInit == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  static String _randomNonce() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  static String _sha256(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}

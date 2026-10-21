import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/http_client.dart';
import '../core/api_config.dart';
import '../core/social_sign_in.dart';
import '../core/token_store.dart';

/// Represents an authenticated user
class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;

  AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      photoUrl: (json['photoUrl'] ?? json['avatar']) as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isAnonymous': isAnonymous,
    };
  }
}

/// Represents authentication response with tokens
class AuthResponse {
  final AuthUser user;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  AuthResponse({
    required this.user,
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['expiresAt'] as num).toInt() * 1000,
              isUtc: true,
            )
          : DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class AuthRepository {
  final HttpClient _httpClient;
  final TokenStore _tokenStore;
  final SocialSignIn _socialSignIn;
  AuthUser? _currentUser;
  final _authChanges = StreamController<AuthUser?>.broadcast(sync: true);
  String? _refreshToken;
  DateTime? _tokenExpiresAt;
  // Tăng mỗi lần đăng nhập/đăng xuất: phản hồi refresh đến muộn của phiên cũ
  // không được ghi đè phiên mới.
  int _generation = 0;
  // Ghi/xoá kho token tuần tự để "xoá" không bị một lần "ghi" chậm hơn đè lên.
  Future<void> _storeQueue = Future.value();

  AuthRepository({
    HttpClient? httpClient,
    TokenStore? tokenStore,
    SocialSignIn? socialSignIn,
  }) : _httpClient = httpClient ?? HttpClient(),
       _tokenStore = tokenStore ?? SecureTokenStore(),
       _socialSignIn = socialSignIn ?? SocialSignIn() {
    _httpClient.onUnauthorized = _refreshAfterUnauthorized;
  }

  AuthUser? get currentUser => _currentUser;

  String? get currentUserId => _currentUser?.id;

  Stream<AuthUser?> get authStateChanges => _authChanges.stream;

  SocialSignIn get socialSignIn => _socialSignIn;

  /// Khôi phục phiên đã lưu khi mở app: đổi refresh token lấy access token mới.
  /// Trả true nếu đã đăng nhập.
  Future<bool> restoreSession() async {
    if (_currentUser != null) return true;
    final generation = _generation;
    final stored = await _tokenStore.read();
    if (stored == null || generation != _generation) return false;
    return await _exchangeRefreshToken(stored.refreshToken, generation) != null;
  }

  /// Sign in anonymously
  Future<AuthResponse?> signInAnonymously() async {
    try {
      final response = await _httpClient.post(
        ApiConfig.anonymousSignInEndpoint,
        body: {},
      );

      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: signInAnonymously error: $e');
    }
    return null;
  }

  /// Sign in with email and password
  Future<AuthResponse?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.loginEndpoint,
        body: {'email': email, 'password': password},
      );

      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: signInWithEmailPassword error: $e');
      rethrow;
    }
    return null;
  }

  /// Register with email and password
  Future<AuthResponse?> registerWithEmailPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.registerEndpoint,
        body: {
          'email': email,
          'username': 'user_${DateTime.now().microsecondsSinceEpoch}',
          'displayName': displayName ?? email.split('@').first,
          'password': password,
        },
      );

      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: registerWithEmailPassword error: $e');
      rethrow;
    }
    return null;
  }

  /// Phương thức đăng nhập mạng xã hội server đang bật.
  Future<({bool google, bool apple})> socialProviders() async {
    try {
      final response = await _httpClient.get(ApiConfig.providersEndpoint);
      if (response is Map<String, dynamic>) {
        return (
          google: response['google'] == true,
          apple: response['apple'] == true,
        );
      }
    } catch (e) {
      debugPrint('AuthRepository: socialProviders error: $e');
    }
    return (google: false, apple: false);
  }

  /// Đăng nhập Google; trả null khi người dùng huỷ.
  Future<AuthResponse?> signInWithGoogle() async {
    final credential = await _socialSignIn.google();
    if (credential == null) return null;
    return _socialLogin(ApiConfig.googleSignInEndpoint, {
      'idToken': credential.token,
      'rawNonce': credential.rawNonce,
    });
  }

  /// Đăng nhập Apple; trả null khi người dùng huỷ.
  Future<AuthResponse?> signInWithApple() async {
    final credential = await _socialSignIn.apple();
    if (credential == null) return null;
    return _socialLogin(ApiConfig.appleSignInEndpoint, {
      'identityToken': credential.token,
      'rawNonce': credential.rawNonce,
      'displayName': ?credential.displayName,
    });
  }

  Future<AuthResponse?> _socialLogin(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _httpClient.post(endpoint, body: body);
      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: social sign-in error: $e');
      rethrow;
    }
    return null;
  }

  /// Refresh access token using refresh token
  Future<AuthResponse?> refreshToken() async {
    final token = _refreshToken;
    if (token == null) {
      debugPrint('AuthRepository: No refresh token available');
      return null;
    }
    return _exchangeRefreshToken(token, _generation);
  }

  Future<bool> _refreshAfterUnauthorized() async =>
      _currentUser != null && await refreshToken() != null;

  // Server xoay vòng refresh token: mỗi lần đổi nhận token mới, token cũ mất hiệu lực.
  Future<AuthResponse?> _exchangeRefreshToken(
    String token,
    int generation,
  ) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.refreshTokenEndpoint,
        body: {'refreshToken': token},
      );
      if (generation != _generation) return null;
      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } on ApiException catch (e) {
      debugPrint('AuthRepository: refreshToken error: $e');
      // Chỉ đăng xuất khi server từ chối token; lỗi mạng thì giữ phiên đã lưu.
      final rejected = e.statusCode == 400 || e.statusCode == 401;
      if (rejected && generation == _generation) _clearAuthState();
    } catch (e) {
      debugPrint('AuthRepository: refreshToken error: $e');
    }
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _httpClient.post(ApiConfig.logoutEndpoint, body: {});
    } catch (e) {
      debugPrint('AuthRepository: signOut error: $e');
    } finally {
      _clearAuthState();
      await _socialSignIn.signOut();
      await _storeQueue;
    }
  }

  /// Set auth state from response
  void _setAuthState(AuthResponse response) {
    _generation++;
    final changed = _currentUser?.id != response.user.id;
    _currentUser = response.user;

    _refreshToken = response.refreshToken;
    _tokenExpiresAt = response.expiresAt;
    _httpClient.setAuthToken(response.accessToken);
    // Refresh chỉ thay token, không phải đổi người dùng: không phát sự kiện để
    // MindraState không xoá dữ liệu đang hiển thị.
    if (changed) _authChanges.add(_currentUser);
    if (response.refreshToken != null) {
      _httpClient.setRefreshToken(response.refreshToken!);
      final session = StoredSession(
        refreshToken: response.refreshToken!,
        user: response.user.toJson(),
      );
      _enqueueStore(() => _tokenStore.write(session));
    }
  }

  /// Clear auth state
  void _clearAuthState() {
    _generation++;
    final hadUser = _currentUser != null;
    _currentUser = null;

    _refreshToken = null;
    _tokenExpiresAt = null;
    _httpClient.clearAuthTokens();
    _enqueueStore(_tokenStore.clear);
    if (hadUser) _authChanges.add(null);
  }

  void _enqueueStore(Future<void> Function() op) {
    _storeQueue = _storeQueue.then((_) => op()).catchError((Object e) {
      debugPrint('AuthRepository: token store error: $e');
    });
  }

  /// Check if token is expired
  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    return DateTime.now().isAfter(_tokenExpiresAt!);
  }

  /// Check if token needs refresh (within 5 minutes of expiry)
  bool get shouldRefreshToken {
    if (_tokenExpiresAt == null) return false;
    return DateTime.now()
        .add(const Duration(minutes: 5))
        .isAfter(_tokenExpiresAt!);
  }
}

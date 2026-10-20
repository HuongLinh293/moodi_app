import 'package:flutter/foundation.dart';
import '../core/http_client.dart';
import '../core/api_config.dart';

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
      photoUrl: json['photoUrl'] as String?,
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
      expiresAt: DateTime.parse(
        json['expiresAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class AuthRepository {
  final HttpClient _httpClient;
  AuthUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiresAt;

  AuthRepository({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  AuthUser? get currentUser => _currentUser;

  String? get currentUserId => _currentUser?.id;

  /// Stream to listen to auth state changes
  /// Note: This simulates Firebase's authStateChanges.
  /// In a real implementation, you might use a broadcast stream controller
  Stream<AuthUser?> get authStateChanges {
    // Return a stream that emits the current user
    return Stream.value(_currentUser);
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
        body: {
          'email': email,
          'password': password,
        },
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
    String password,
  ) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.registerEndpoint,
        body: {
          'email': email,
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

  /// Sign in with Google (requires token from native implementation)
  Future<AuthResponse?> signInWithGoogle({required String googleToken}) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.googleSignInEndpoint,
        body: {
          'idToken': googleToken,
        },
      );

      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: signInWithGoogle error: $e');
      rethrow;
    }
    return null;
  }

  /// Sign in with Apple (requires token from native implementation)
  Future<AuthResponse?> signInWithApple({required String appleToken}) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.appleSignInEndpoint,
        body: {
          'identityToken': appleToken,
        },
      );

      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: signInWithApple error: $e');
      rethrow;
    }
    return null;
  }

  /// Refresh access token using refresh token
  Future<AuthResponse?> refreshToken() async {
    if (_refreshToken == null) {
      debugPrint('AuthRepository: No refresh token available');
      return null;
    }

    try {
      final response = await _httpClient.post(
        ApiConfig.refreshTokenEndpoint,
        body: {
          'refreshToken': _refreshToken,
        },
      );

      if (response is Map<String, dynamic>) {
        final authResponse = AuthResponse.fromJson(response);
        _setAuthState(authResponse);
        return authResponse;
      }
    } catch (e) {
      debugPrint('AuthRepository: refreshToken error: $e');
      _clearAuthState();
    }
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _httpClient.post(
        ApiConfig.logoutEndpoint,
        body: {
          'userId': _currentUser?.id,
        },
      );
    } catch (e) {
      debugPrint('AuthRepository: signOut error: $e');
    } finally {
      _clearAuthState();
    }
  }

  /// Set auth state from response
  void _setAuthState(AuthResponse response) {
    _currentUser = response.user;
    _accessToken = response.accessToken;
    _refreshToken = response.refreshToken;
    _tokenExpiresAt = response.expiresAt;
    _httpClient.setAuthToken(response.accessToken);
    if (response.refreshToken != null) {
      _httpClient.setRefreshToken(response.refreshToken!);
    }
  }

  /// Clear auth state
  void _clearAuthState() {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiresAt = null;
    _httpClient.clearAuthTokens();
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

  /// Restore auth state from stored tokens
  Future<void> restoreAuthState({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiresAt = expiresAt;
    _httpClient.setAuthToken(accessToken);
    if (refreshToken != null) {
      _httpClient.setRefreshToken(refreshToken);
    }

    // Try to get current user info from API
    try {
      // This would require a /me or /current-user endpoint
      debugPrint('AuthRepository: Auth state restored');
    } catch (e) {
      debugPrint('AuthRepository: Failed to restore auth state: $e');
      _clearAuthState();
    }
  }
}

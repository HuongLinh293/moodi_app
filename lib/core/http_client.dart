import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? response;
  final String? _code;
  String get code =>
      _code ??
      switch (statusCode) {
        401 => 'unauthenticated',
        403 => 'permission-denied',
        404 => 'not-found',
        408 => 'deadline-exceeded',
        409 => 'failed-precondition',
        429 => 'resource-exhausted',
        501 => 'unimplemented',
        500 => 'internal',
        _ => 'unavailable',
      };

  ApiException({
    required this.message,
    this.statusCode,
    this.response,
    this._code,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// HTTP client for making API requests
class HttpClient {
  static final HttpClient _instance = HttpClient._internal();

  late http.Client _httpClient;
  String? _authToken;

  HttpClient._internal() {
    _httpClient = http.Client();
  }

  HttpClient.withClient(http.Client client) : _httpClient = client;

  factory HttpClient() {
    return _instance;
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Set refresh token
  void setRefreshToken(String token) {
    // Refresh tokens are owned by AuthRepository.
  }

  /// Clear authentication tokens
  void clearAuthTokens() {
    _authToken = null;
  }

  /// Get current auth token
  String? get authToken => _authToken;

  /// Build headers with authorization
  Map<String, String> _buildHeaders({Map<String, String>? additional}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (additional != null) {
      headers.addAll(additional);
    }

    return headers;
  }

  /// Parse response body
  dynamic _parseResponse(String body) {
    try {
      return jsonDecode(body);
    } catch (e) {
      debugPrint('HttpClient: Failed to parse response: $e');
      return body;
    }
  }

  /// Handle response errors
  Never _handleErrorResponse(http.Response response) {
    String errorMessage = 'Request failed with status ${response.statusCode}';
    String? code;

    try {
      final data = jsonDecode(response.body);
      final message = data is Map ? data['message'] : null;
      if (message is String) {
        errorMessage = message;
      } else if (message is List && message.isNotEmpty) {
        // ValidationPipe của NestJS trả mảng lỗi.
        errorMessage = message.join('; ');
      }
      // Mã lỗi nghiệp vụ (vd: already-exists) chính xác hơn suy từ status.
      if (data is Map && data['code'] is String) code = data['code'] as String;
      if (message == null && data is Map && data.containsKey('error')) {
        errorMessage = data['error'] as String;
      }
    } catch (e) {
      debugPrint('HttpClient: Failed to parse error response: $e');
    }

    throw ApiException(
      message: errorMessage,
      statusCode: response.statusCode,
      response: response.body,
      code: code,
    );
  }

  /// Gọi khi một request bị 401: trả true nếu đã có access token mới để thử lại.
  /// AuthRepository gắn hàm refresh token vào đây.
  Future<bool> Function()? onUnauthorized;
  Future<bool>? _refreshing;

  Future<dynamic> _send(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    bool retried = false,
    Duration? timeout,
  }) async {
    final http.Response response;
    try {
      final uri = Uri.parse(
        '${ApiConfig.apiEndpoint}$endpoint${queryParameters != null ? '?${Uri(queryParameters: queryParameters).query}' : ''}',
      );

      debugPrint('HttpClient: $method $uri');

      final request = http.Request(method, uri)
        ..headers.addAll(_buildHeaders(additional: headers));
      if (body != null) request.body = jsonEncode(body);

      response = await _httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout ?? const Duration(seconds: ApiConfig.requestTimeoutSeconds),
            onTimeout: () =>
                throw ApiException(message: 'Request timeout', statusCode: 408),
          );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('HttpClient: $method error: $e');
      throw ApiException(message: 'Failed to complete $method request: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _parseResponse(response.body);
    }

    // Access token hết hạn: refresh một lần (dùng chung cho các request song
    // song) rồi thử lại. Không áp dụng cho chính các route /auth.
    if (response.statusCode == 401 &&
        !retried &&
        onUnauthorized != null &&
        !endpoint.startsWith(ApiConfig.authEndpoint)) {
      _refreshing ??= onUnauthorized!().whenComplete(() => _refreshing = null);
      if (await _refreshing!) {
        return _send(
          method,
          endpoint,
          body: body,
          headers: headers,
          queryParameters: queryParameters,
          retried: true,
          timeout: timeout,
        );
      }
    }
    _handleErrorResponse(response);
  }

  /// Perform GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) => _send(
    'GET',
    endpoint,
    headers: headers,
    queryParameters: queryParameters,
  );

  /// Perform POST request
  Future<dynamic> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration? timeout,
  }) => _send('POST', endpoint, body: body, headers: headers, timeout: timeout);

  /// Perform PUT request
  Future<dynamic> put(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) => _send('PUT', endpoint, body: body, headers: headers);

  /// Perform PATCH request
  Future<dynamic> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) => _send('PATCH', endpoint, body: body, headers: headers);

  /// Perform DELETE request
  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) =>
      _send('DELETE', endpoint, headers: headers);

  /// Dispose HTTP client
  void dispose() {
    _httpClient.close();
  }
}

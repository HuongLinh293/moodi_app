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

  ApiException({
    required this.message,
    this.statusCode,
    this.response,
  });

  @override
  String toString() =>
      'ApiException: $message (Status: $statusCode) - Response: $response';
}

/// HTTP client for making API requests
class HttpClient {
  static final HttpClient _instance = HttpClient._internal();

  late http.Client _httpClient;
  String? _authToken;
  String? _refreshToken;

  HttpClient._internal() {
    _httpClient = http.Client();
  }

  factory HttpClient() {
    return _instance;
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Set refresh token
  void setRefreshToken(String token) {
    _refreshToken = token;
  }

  /// Clear authentication tokens
  void clearAuthTokens() {
    _authToken = null;
    _refreshToken = null;
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
  void _handleErrorResponse(http.Response response) {
    String errorMessage = 'Request failed with status ${response.statusCode}';

    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('message')) {
        errorMessage = data['message'] as String;
      } else if (data is Map && data.containsKey('error')) {
        errorMessage = data['error'] as String;
      }
    } catch (e) {
      debugPrint('HttpClient: Failed to parse error response: $e');
    }

    throw ApiException(
      message: errorMessage,
      statusCode: response.statusCode,
      response: response.body,
    );
  }

  /// Perform GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.apiEndpoint}$endpoint${queryParameters != null ? '?${Uri(queryParameters: queryParameters).query}' : ''}',
      );

      debugPrint('HttpClient: GET $uri');

      final response = await _httpClient
          .get(
            uri,
            headers: _buildHeaders(additional: headers),
          )
          .timeout(
            const Duration(seconds: ApiConfig.requestTimeoutSeconds),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('HttpClient: GET error: $e');
      throw ApiException(message: 'Failed to complete GET request: $e');
    }
  }

  /// Perform POST request
  Future<dynamic> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiEndpoint}$endpoint');

      debugPrint('HttpClient: POST $uri - Body: $body');

      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(additional: headers),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: ApiConfig.requestTimeoutSeconds),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('HttpClient: POST error: $e');
      throw ApiException(message: 'Failed to complete POST request: $e');
    }
  }

  /// Perform PUT request
  Future<dynamic> put(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiEndpoint}$endpoint');

      debugPrint('HttpClient: PUT $uri - Body: $body');

      final response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(additional: headers),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: ApiConfig.requestTimeoutSeconds),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('HttpClient: PUT error: $e');
      throw ApiException(message: 'Failed to complete PUT request: $e');
    }
  }

  /// Perform PATCH request
  Future<dynamic> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiEndpoint}$endpoint');

      debugPrint('HttpClient: PATCH $uri - Body: $body');

      final response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(additional: headers),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: ApiConfig.requestTimeoutSeconds),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('HttpClient: PATCH error: $e');
      throw ApiException(message: 'Failed to complete PATCH request: $e');
    }
  }

  /// Perform DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiEndpoint}$endpoint');

      debugPrint('HttpClient: DELETE $uri');

      final response = await _httpClient
          .delete(
            uri,
            headers: _buildHeaders(additional: headers),
          )
          .timeout(
            const Duration(seconds: ApiConfig.requestTimeoutSeconds),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('HttpClient: DELETE error: $e');
      throw ApiException(message: 'Failed to complete DELETE request: $e');
    }
  }

  /// Dispose HTTP client
  void dispose() {
    _httpClient.close();
  }
}

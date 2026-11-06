/// API configuration for the Moodi app
class ApiConfig {
  /// Base URL for the API (development: localhost:3000, production: https://api.moodi.app)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Global prefix của NestJS (API_PREFIX, mặc định 'api')
  static const String apiVersion = '/api';

  /// Full API endpoint
  static String get apiEndpoint => baseUrl + apiVersion;

  // Personal-data API (backend/src/entries, moments, shared-gardens).
  static const entriesEndpoint = '/entries';
  static const momentsEndpoint = '/moments';
  static const sharedGardenEndpoint = '/shared-gardens';
  static const reflectionEndpoint = '/reflections';
  static const generateReflectionEndpoint = '/reflections/generate';

  /// Authentication endpoints
  static const String authEndpoint = '/auth';
  static const String loginEndpoint = '$authEndpoint/login';
  static const String registerEndpoint = '$authEndpoint/register';
  static const String logoutEndpoint = '$authEndpoint/logout';
  static const String refreshTokenEndpoint = '$authEndpoint/refresh-token';
  static const String googleSignInEndpoint = '$authEndpoint/google';
  static const String appleSignInEndpoint = '$authEndpoint/apple';
  static const String anonymousSignInEndpoint = '$authEndpoint/anonymous';
  static const String providersEndpoint = '$authEndpoint/providers';

  /// Community gateway (action-based, port từ callable `community` cũ)
  static const String communityEndpoint = '/community';

  /// Users endpoints
  static const String usersEndpoint = '/users';
  static String userById(String id) => '$usersEndpoint/$id';
  static const String userSearchEndpoint = '$usersEndpoint/search';
  static String userStats(String id) => '$usersEndpoint/$id/stats';
  static String userAvatar(String id) => '$usersEndpoint/$id/avatar';

  static const String storageEndpoint = '/storage';
  static const String uploadEndpoint = '$storageEndpoint/upload';
  static String storageFile(String id) => '$storageEndpoint/$id';
  static String downloadFile(String id) => '$storageEndpoint/$id/content';
  static String filesByEntity(String entityType, String entityId) =>
      '$storageEndpoint/related/$entityType/$entityId';

  /// Request timeout in seconds
  static const int requestTimeoutSeconds = 30;

  /// Connection timeout in seconds
  static const int connectionTimeoutSeconds = 10;
}

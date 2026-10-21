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

  /// Posts endpoints
  static const String postsEndpoint = '/posts';
  static String postById(String id) => '$postsEndpoint/$id';
  static String likePost(String id) => '$postsEndpoint/$id/like';

  /// Friends endpoints
  static const String friendsEndpoint = '/friends';
  static const String friendRequestsEndpoint = '$friendsEndpoint/requests';
  static String acceptFriendRequest(String id) =>
      '$friendRequestsEndpoint/$id/accept';
  static String rejectFriendRequest(String id) => '$friendRequestsEndpoint/$id';
  static String removeFriend(String id) => '$friendsEndpoint/$id';
  static const String friendSuggestionsEndpoint =
      '$friendsEndpoint/suggestions';

  /// Groups endpoints
  static const String groupsEndpoint = '/groups';
  static String groupById(String id) => '$groupsEndpoint/$id';
  static String groupMembers(String id) => '$groupsEndpoint/$id/members';
  static String addGroupMember(String id) => '$groupsEndpoint/$id/members';
  static String removeGroupMember(String groupId, String userId) =>
      '$groupsEndpoint/$groupId/members/$userId';
  static String leaveGroup(String id) => '$groupsEndpoint/$id/leave';

  /// Chat endpoints
  static const String chatEndpoint = '/chat';
  static const String conversationsEndpoint = '$chatEndpoint/conversations';
  static String conversationById(String id) => '$conversationsEndpoint/$id';
  static String conversationMessages(String id) =>
      '$conversationsEndpoint/$id/messages';
  static String sendMessage(String id) => '$conversationsEndpoint/$id/messages';

  /// Storage endpoints
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

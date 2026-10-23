# Flutter REST API Integration Guide

Step-by-step guide for integrating Flutter with the Moodi NestJS REST API.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Infrastructure](#core-infrastructure)
4. [API Configuration](#api-configuration)
5. [HTTP Client Setup](#http-client-setup)
6. [Repository Pattern](#repository-pattern)
7. [Authentication Flow](#authentication-flow)
8. [Making API Calls](#making-api-calls)
9. [Error Handling](#error-handling)
10. [Real-time Features](#real-time-features)
11. [Testing](#testing)
12. [Best Practices](#best-practices)

---

## Overview

The Moodi app uses a **clean architecture** with repository pattern for API integration:

```
UI Layer (Screens)
    ↓
State Management (MindraState)
    ↓
Repositories (Business Logic)
    ↓
HTTP Client (Network)
    ↓
REST API (NestJS Backend)
```

### Benefits

- **Testable**: Easy to mock repositories
- **Maintainable**: Clear separation of concerns
- **Scalable**: Add new features without touching HTTP client
- **Flexible**: Switch backends without changing UI code

---

## Architecture

### Layer Responsibilities

**UI Layer** (`lib/screens/`):
- Display data to users
- Handle user interactions
- Call state management

**State Management** (`lib/state/mindra_state.dart`):
- Manage app-wide state
- Coordinate between repositories
- Update UI when data changes

**Repositories** (`lib/repositories/`):
- Business logic for each feature
- Transform API responses
- Cache and pagination

**HTTP Client** (`lib/core/http_client.dart`):
- Handle HTTP requests/responses
- Manage authentication tokens
- Error handling and retries

**API Config** (`lib/core/api_config.dart`):
- Centralized endpoint definitions
- Base URL configuration
- Constants and helpers

---

## Core Infrastructure

### 1. API Configuration

**File**: `lib/core/api_config.dart`

```dart
class ApiConfig {
  // Base URL - change this for different environments
  static const String baseUrl = 'http://localhost:3000';
  static const String apiVersion = '';  // Empty for NestJS
  
  // Authentication endpoints
  static const String authLogin = '$baseUrl/auth/login';
  static const String authRegister = '$baseUrl/auth/register';
  static const String authRefresh = '$baseUrl/auth/refresh';
  static const String authLogout = '$baseUrl/auth/logout';
  
  // User endpoints
  static const String getUser = '$baseUrl/users';
  static const String updateUser = '$baseUrl/users';
  static const String getUserStats = '$baseUrl/users/stats';
  static const String searchUsers = '$baseUrl/users/search';
  
  // Post endpoints
  static const String getPosts = '$baseUrl/posts';
  static const String createPost = '$baseUrl/posts';
  static const String likePost = '$baseUrl/posts/like';
  static const String unlikePost = '$baseUrl/posts/unlike';
  
  // Friend endpoints
  static const String getFriends = '$baseUrl/friends';
  static const String sendFriendRequest = '$baseUrl/friends/requests';
  static const String acceptFriendRequest = '$baseUrl/friends/requests/accept';
  
  // Group endpoints
  static const String getGroups = '$baseUrl/groups';
  static const String createGroup = '$baseUrl/groups';
  
  // Chat endpoints
  static const String getConversations = '$baseUrl/chat/conversations';
  static const String sendMessage = '$baseUrl/chat/messages';
  
  // Storage endpoints
  static const String uploadFile = '$baseUrl/storage/upload';
  static const String getFile = '$baseUrl/storage';
  
  // WebSocket
  static const String webSocketUrl = 'ws://localhost:3000';
  
  // Pagination defaults
  static const int defaultPageSize = 20;
  static const int defaultPage = 1;
  
  // Request timeouts (in seconds)
  static const int connectTimeout = 10;
  static const int receiveTimeout = 30;
  
  // Error messages
  static const Map<int, String> statusMessages = {
    400: 'Bad request',
    401: 'Unauthorized',
    403: 'Forbidden',
    404: 'Not found',
    500: 'Server error',
    503: 'Service unavailable',
  };
}
```

### 2. HTTP Client

**File**: `lib/core/http_client.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;
  
  ApiException({
    required this.message,
    this.statusCode,
    this.response,
  });
  
  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  
  late String _accessToken;
  late String _refreshToken;
  
  factory HttpClient() {
    return _instance;
  }
  
  HttpClient._internal();
  
  // Set authentication tokens
  void setAuthToken(String token) {
    _accessToken = token;
  }
  
  void setRefreshToken(String token) {
    _refreshToken = token;
  }
  
  // Get headers with authentication
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_accessToken.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
    };
  }
  
  // GET request
  Future<dynamic> get(String endpoint) async {
    try {
      final url = Uri.parse(endpoint);
      final response = await http.get(
        url,
        headers: _getHeaders(),
      ).timeout(
        Duration(seconds: ApiConfig.receiveTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw ApiException(
        message: 'Request failed: $e',
        statusCode: null,
      );
    }
  }
  
  // POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse(endpoint);
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(
        Duration(seconds: ApiConfig.receiveTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw ApiException(
        message: 'Request failed: $e',
        statusCode: null,
      );
    }
  }
  
  // PATCH request
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse(endpoint);
      final response = await http.patch(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(
        Duration(seconds: ApiConfig.receiveTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw ApiException(
        message: 'Request failed: $e',
        statusCode: null,
      );
    }
  }
  
  // DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final url = Uri.parse(endpoint);
      final response = await http.delete(
        url,
        headers: _getHeaders(),
      ).timeout(
        Duration(seconds: ApiConfig.receiveTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw ApiException(
        message: 'Request failed: $e',
        statusCode: null,
      );
    }
  }
  
  // Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    try {
      final data = jsonDecode(response.body);
      
      if (statusCode >= 200 && statusCode < 300) {
        return data;
      } else if (statusCode == 401) {
        // Token expired, could refresh here
        throw ApiException(
          message: data['message'] ?? 'Unauthorized',
          statusCode: statusCode,
          response: data,
        );
      } else {
        throw ApiException(
          message: data['message'] ?? 'Error',
          statusCode: statusCode,
          response: data,
        );
      }
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse response: $e',
        statusCode: statusCode,
        response: response.body,
      );
    }
  }
}
```

---

## API Configuration

### Environment Setup

**Development**:
```dart
// lib/core/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000';
}
```

**Production**:
```dart
// lib/core/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://api.moodi.app';
}
```

### Build Variants

Use flavors for multiple environments:

```bash
# Development
flutter run --flavor development

# Staging
flutter run --flavor staging

# Production
flutter run --flavor production
```

---

## HTTP Client Setup

### Initialization in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize HTTP client
  final httpClient = HttpClient();
  
  // Restore saved tokens if available
  final savedToken = await _getSavedToken();
  if (savedToken != null) {
    httpClient.setAuthToken(savedToken);
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MindraState(httpClient),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<String?> _getSavedToken() async {
  // Implement secure token retrieval
  // e.g., from SharedPreferences or flutter_secure_storage
  return null;
}
```

---

## Repository Pattern

### Base Repository

```dart
abstract class BaseRepository {
  const BaseRepository();
  
  Future<T> handleException<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ApiException catch (e) {
      print('API Error: ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected error: $e');
      rethrow;
    }
  }
}
```

### Example: UserRepository

**File**: `lib/repositories/user_repository.dart`

```dart
class UserRepository extends BaseRepository {
  final HttpClient _httpClient;
  
  UserRepository({required HttpClient httpClient})
      : _httpClient = httpClient;
  
  // Get user profile
  Future<UserProfile> getUserProfile(String userId) async {
    return handleException(() async {
      final response = await _httpClient.get(
        '${ApiConfig.getUser}/$userId',
      );
      
      return UserProfile.fromJson(response['data']);
    });
  }
  
  // Update user profile
  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    return handleException(() async {
      final response = await _httpClient.patch(
        '${ApiConfig.updateUser}/$userId',
        {
          'displayName': displayName,
          'bio': bio,
        },
      );
      
      return UserProfile.fromJson(response['data']);
    });
  }
  
  // Search users
  Future<List<UserProfile>> searchUsers(String query) async {
    return handleException(() async {
      final response = await _httpClient.get(
        '${ApiConfig.searchUsers}?q=$query',
      );
      
      return List<UserProfile>.from(
        (response['data'] as List).map(
          (user) => UserProfile.fromJson(user),
        ),
      );
    });
  }
  
  // Get user statistics
  Future<UserStats> getUserStats(String userId) async {
    return handleException(() async {
      final response = await _httpClient.get(
        '${ApiConfig.getUserStats}/$userId',
      );
      
      return UserStats.fromJson(response['data']);
    });
  }
}
```

### Models

```dart
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final DateTime createdAt;
  
  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.bio,
    required this.createdAt,
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'] ?? '',
      photoUrl: json['photoUrl'],
      bio: json['bio'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class UserStats {
  final int postCount;
  final int friendCount;
  final int groupCount;
  
  UserStats({
    required this.postCount,
    required this.friendCount,
    required this.groupCount,
  });
  
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      postCount: json['postCount'] ?? 0,
      friendCount: json['friendCount'] ?? 0,
      groupCount: json['groupCount'] ?? 0,
    );
  }
}
```

---

## Authentication Flow

### Complete Auth Setup

**File**: `lib/repositories/auth_repository.dart`

```dart
class AuthRepository extends BaseRepository {
  final HttpClient _httpClient;
  
  AuthRepository({required HttpClient httpClient})
      : _httpClient = httpClient;
  
  // Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return handleException(() async {
      final response = await _httpClient.post(
        ApiConfig.authLogin,
        {
          'email': email,
          'password': password,
        },
      );
      
      final authResponse = AuthResponse.fromJson(response);
      
      // Save tokens
      _httpClient.setAuthToken(authResponse.accessToken);
      _httpClient.setRefreshToken(authResponse.refreshToken ?? '');
      
      // Persist tokens (implement secure storage)
      await _saveTokens(authResponse);
      
      return authResponse;
    });
  }
  
  // Register new account
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return handleException(() async {
      final response = await _httpClient.post(
        ApiConfig.authRegister,
        {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      
      final authResponse = AuthResponse.fromJson(response);
      
      // Save tokens
      _httpClient.setAuthToken(authResponse.accessToken);
      _httpClient.setRefreshToken(authResponse.refreshToken ?? '');
      
      await _saveTokens(authResponse);
      
      return authResponse;
    });
  }
  
  // Refresh access token
  Future<AuthResponse> refreshAccessToken(String refreshToken) async {
    return handleException(() async {
      final response = await _httpClient.post(
        ApiConfig.authRefresh,
        {'refreshToken': refreshToken},
      );
      
      final authResponse = AuthResponse.fromJson(response);
      
      _httpClient.setAuthToken(authResponse.accessToken);
      _httpClient.setRefreshToken(authResponse.refreshToken ?? '');
      
      await _saveTokens(authResponse);
      
      return authResponse;
    });
  }
  
  // Logout
  Future<void> logout() async {
    return handleException(() async {
      await _httpClient.post(ApiConfig.authLogout, {});
      
      // Clear stored tokens
      await _clearTokens();
    });
  }
  
  // Save tokens to secure storage
  Future<void> _saveTokens(AuthResponse response) async {
    // Use flutter_secure_storage for production
    // const storage = FlutterSecureStorage();
    // await storage.write(key: 'accessToken', value: response.accessToken);
  }
  
  // Clear stored tokens
  Future<void> _clearTokens() async {
    // Use flutter_secure_storage for production
    // const storage = FlutterSecureStorage();
    // await storage.delete(key: 'accessToken');
  }
}

class AuthResponse {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final UserProfile user;
  
  AuthResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    required this.user,
  });
  
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      expiresAt: DateTime.parse(json['expiresAt']),
      user: UserProfile.fromJson(json['user']),
    );
  }
}
```

---

## Making API Calls

### In State Management (MindraState)

```dart
class MindraState extends ChangeNotifier {
  final HttpClient _httpClient;
  late UserRepository _userRepository;
  late PostRepository _postRepository;
  
  UserProfile? currentUser;
  List<Post> posts = [];
  bool isLoading = false;
  
  MindraState(this._httpClient) {
    _userRepository = UserRepository(httpClient: _httpClient);
    _postRepository = PostRepository(httpClient: _httpClient);
  }
  
  // Get current user profile
  Future<void> fetchCurrentUser(String userId) async {
    isLoading = true;
    notifyListeners();
    
    try {
      currentUser = await _userRepository.getUserProfile(userId);
    } catch (e) {
      print('Error fetching user: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  
  // Get posts
  Future<void> fetchPosts({int page = 1, int pageSize = 20}) async {
    isLoading = true;
    notifyListeners();
    
    try {
      final postsPage = await _postRepository.getPosts(
        page: page,
        pageSize: pageSize,
      );
      posts = postsPage.items;
    } catch (e) {
      print('Error fetching posts: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  
  // Create post
  Future<Post> createPost({
    required String content,
    String? imageUrl,
  }) async {
    try {
      final post = await _postRepository.createPost(
        content: content,
        imageUrl: imageUrl,
      );
      
      posts.insert(0, post);
      notifyListeners();
      
      return post;
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }
}
```

### In UI Screens

```dart
class PostsFeedView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: Consumer<MindraState>(
        builder: (context, mindraState, child) {
          if (mindraState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return ListView.builder(
            itemCount: mindraState.posts.length,
            itemBuilder: (context, index) {
              final post = mindraState.posts[index];
              return PostCard(post: post);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  void _showCreatePostDialog(BuildContext context) {
    final mindraState = Provider.of<MindraState>(context, listen: false);
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Post'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'What\'s on your mind?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await mindraState.createPost(content: controller.text);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
```

---

## Error Handling

### Global Error Handler

```dart
class AppErrorHandler {
  static void handleError(BuildContext context, dynamic error) {
    String message = 'An error occurred';
    
    if (error is ApiException) {
      message = error.message;
      
      if (error.statusCode == 401) {
        // Handle unauthorized - redirect to login
        Navigator.of(context).pushReplacementNamed('/login');
      } else if (error.statusCode == 403) {
        message = 'You don\'t have permission';
      } else if (error.statusCode == 404) {
        message = 'Resource not found';
      } else if (error.statusCode == 500) {
        message = 'Server error. Please try again later';
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  static void showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: CircularProgressIndicator(),
      ),
    );
  }
  
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }
}
```

### Usage

```dart
try {
  await mindraState.fetchCurrentUser(userId);
} catch (e) {
  AppErrorHandler.handleError(context, e);
}
```

---

## Real-time Features

### Polling-based Real-time Updates

```dart
class PostRepository extends BaseRepository {
  // Stream posts with polling
  Stream<List<Post>> watchPosts() {
    return Stream.periodic(
      const Duration(seconds: 5),
      (_) => _fetchPostsOnce(),
    ).asyncExpand((future) => future.asStream());
  }
  
  Future<List<Post>> _fetchPostsOnce() async {
    try {
      final response = await _httpClient.get(ApiConfig.getPosts);
      return List<Post>.from(
        (response['data'] as List).map((p) => Post.fromJson(p)),
      );
    } catch (e) {
      return [];
    }
  }
}

// Use in state management
class MindraState extends ChangeNotifier {
  late StreamSubscription _postsSubscription;
  
  void startListeningToPosts() {
    _postsSubscription = _postRepository.watchPosts().listen((posts) {
      this.posts = posts;
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _postsSubscription.cancel();
    super.dispose();
  }
}
```

### WebSocket Integration (Optional)

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatRepository {
  late WebSocketChannel _channel;
  
  void connect(String token) {
    final url = Uri.parse('${ApiConfig.webSocketUrl}/chat');
    _channel = WebSocketChannel.connect(url);
    
    // Send authentication
    _channel.sink.add(jsonEncode({'token': token}));
  }
  
  Stream<Message> get messages {
    return _channel.stream
        .map((message) => Message.fromJson(jsonDecode(message)))
        .asBroadcastStream();
  }
  
  void sendMessage(String message) {
    _channel.sink.add(jsonEncode({'type': 'message', 'data': message}));
  }
  
  void dispose() {
    _channel.sink.close();
  }
}
```

---

## Testing

### Unit Test Example

```dart
void main() {
  group('UserRepository', () {
    late MockHttpClient mockHttpClient;
    late UserRepository userRepository;
    
    setUp(() {
      mockHttpClient = MockHttpClient();
      userRepository = UserRepository(httpClient: mockHttpClient);
    });
    
    test('getUserProfile returns UserProfile', () async {
      // Arrange
      const userId = 'user123';
      when(mockHttpClient.get(any)).thenAnswer(
        (_) async => {
          'data': {
            'id': userId,
            'email': 'user@example.com',
            'displayName': 'John',
            'createdAt': '2024-10-20T00:00:00Z',
          }
        },
      );
      
      // Act
      final result = await userRepository.getUserProfile(userId);
      
      // Assert
      expect(result.id, equals(userId));
      expect(result.email, equals('user@example.com'));
    });
  });
}
```

### Integration Test Example

```dart
void main() {
  group('Authentication Flow', () {
    late HttpClient httpClient;
    late AuthRepository authRepository;
    
    setUp(() {
      httpClient = HttpClient();
      authRepository = AuthRepository(httpClient: httpClient);
    });
    
    test('User can login with valid credentials', () async {
      final response = await authRepository.login(
        email: 'alice@moodi.com',
        password: 'password123',
      );
      
      expect(response.accessToken, isNotEmpty);
      expect(response.user.email, equals('alice@moodi.com'));
    });
  });
}
```

---

## Best Practices

### 1. Always Use Repositories

❌ **Don't do this in UI**:
```dart
final response = await http.get(Uri.parse('http://localhost:3000/posts'));
```

✅ **Do this instead**:
```dart
final posts = await postRepository.getPosts();
```

### 2. Handle Errors Gracefully

❌ **Don't do this**:
```dart
try {
  await fetchData();
} catch (e) {
  print(e);
}
```

✅ **Do this instead**:
```dart
try {
  await fetchData();
} on ApiException catch (e) {
  _showErrorDialog(e.message);
} catch (e) {
  _showErrorDialog('Unexpected error occurred');
}
```

### 3. Use Async/Await

❌ **Don't use callbacks**:
```dart
fetchData().then((data) => updateUI(data));
```

✅ **Use async/await**:
```dart
final data = await fetchData();
updateUI(data);
```

### 4. Cache When Appropriate

```dart
class UserRepository {
  final Map<String, UserProfile> _cache = {};
  
  Future<UserProfile> getUserProfile(String userId) async {
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }
    
    final profile = await _fetchUserProfile(userId);
    _cache[userId] = profile;
    return profile;
  }
  
  void clearCache() => _cache.clear();
}
```

### 5. Use Constants

```dart
// Good
const String baseUrl = 'http://localhost:3000';

// Avoid
final url = 'http://localhost:3000';  // Changed elsewhere
```

### 6. Validate Input

```dart
Future<void> createPost({required String content}) async {
  if (content.trim().isEmpty) {
    throw ApiException(message: 'Post content cannot be empty');
  }
  
  // Proceed with API call
}
```

### 7. Use Type Safety

```dart
// Good - explicit types
Future<List<Post>> getPosts() => ...;

// Avoid - ambiguous types
Future<dynamic> getPosts() => ...;
```

### 8. Handle Token Expiry

```dart
class HttpClient {
  bool get shouldRefreshToken {
    if (_expiresAt == null) return false;
    final now = DateTime.now();
    final timeUntilExpiry = _expiresAt!.difference(now);
    return timeUntilExpiry.inMinutes < 5;  // Refresh if less than 5 min
  }
}
```

---

## Configuration by Environment

### Development

```dart
// lib/core/api_config.dart
const String baseUrl = 'http://localhost:3000';
const String logLevel = 'debug';
const bool enableMockData = false;
```

### Staging

```dart
const String baseUrl = 'https://staging-api.moodi.app';
const String logLevel = 'info';
const bool enableMockData = false;
```

### Production

```dart
const String baseUrl = 'https://api.moodi.app';
const String logLevel = 'warn';
const bool enableMockData = false;
```

---

## Debugging

### Enable Request Logging

```dart
// In http_client.dart
void _logRequest(String endpoint, Map<String, String> headers) {
  print('📤 REQUEST: $endpoint');
  print('Headers: $headers');
}

void _logResponse(http.Response response) {
  print('📥 RESPONSE: ${response.statusCode}');
  print('Body: ${response.body}');
}
```

### Use REST Client Extension

VS Code extension: [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

Create `requests.http`:
```http
@baseUrl = http://localhost:3000

### Get all posts
GET {{baseUrl}}/posts

### Create post
POST {{baseUrl}}/posts
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "content": "Hello, Moodi!",
  "imageUrl": "https://example.com/image.jpg"
}

### Like post
POST {{baseUrl}}/posts/post123/like
Authorization: Bearer YOUR_TOKEN
```

---

## Quick Reference

### Common API Patterns

```dart
// Paginated list
Future<PaginatedResponse<T>> getItems({int page = 1, int pageSize = 20});

// Single item
Future<T> getItem(String id);

// Create
Future<T> create(Map<String, dynamic> data);

// Update
Future<T> update(String id, Map<String, dynamic> data);

// Delete
Future<void> delete(String id);

// Search
Future<List<T>> search(String query);
```

### Repository Template

```dart
class NewFeatureRepository extends BaseRepository {
  final HttpClient _httpClient;
  
  NewFeatureRepository({required HttpClient httpClient})
      : _httpClient = httpClient;
  
  Future<List<Item>> getItems() async {
    return handleException(() async {
      final response = await _httpClient.get('${ApiConfig.baseUrl}/items');
      return List<Item>.from(
        (response['data'] as List).map((item) => Item.fromJson(item)),
      );
    });
  }
}
```

---

## Resources

- [NestJS Documentation](https://docs.nestjs.com/)
- [Flutter HTTP Requests](https://flutter.dev/docs/cookbook/networking/fetch-data)
- [REST API Best Practices](https://restfulapi.net/)
- [Clean Architecture in Flutter](https://resocoder.com/flutter-clean-architecture)

---

**Last Updated**: October 20, 2024  
**Version**: 1.0  
**Status**: Complete and Production Ready

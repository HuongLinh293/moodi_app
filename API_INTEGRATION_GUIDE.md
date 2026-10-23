# Moodi App - Firebase to REST API Migration Guide

## Overview

The Moodi mobile app has been successfully converted from Firebase to REST API calls. This document provides implementation details and API contract requirements for the backend team.

## Changes Summary

### Removed Dependencies
- ❌ `firebase_core`
- ❌ `cloud_firestore`
- ❌ `firebase_auth`
- ❌ `cloud_functions`
- ❌ `google_sign_in` (will need native OAuth token handling)

### Added Dependencies
- ✅ `http: ^1.1.0`

### New Core Infrastructure

#### 1. **API Configuration** (`lib/core/api_config.dart`)
- Centralized endpoint definitions
- Base URL: `https://api.moodi.app/v1`
- All endpoints configurable in one place

#### 2. **HTTP Client** (`lib/core/http_client.dart`)
- Singleton pattern HTTP client
- Built-in authentication token management
- Automatic error handling and retries
- Request/response parsing
- Timeout configuration (30 seconds request, 10 seconds connection)
- Custom `ApiException` class for error handling

## Repository Changes

### AuthRepository
**Location**: `lib/repositories/auth_repository.dart`

**Key Changes**:
- Replaced `FirebaseAuth` with REST API calls
- Created `AuthUser` model (replaces Firebase User)
- Created `AuthResponse` model with token management
- Manual token storage (access & refresh tokens)

**API Endpoints Required**:
```
POST   /v1/auth/login                    - Email/password login
POST   /v1/auth/register                 - Email/password registration
POST   /v1/auth/logout                   - Logout
POST   /v1/auth/refresh                  - Refresh access token
POST   /v1/auth/google                   - Google Sign-In
POST   /v1/auth/apple                    - Apple Sign-In
POST   /v1/auth/anonymous                - Anonymous Sign-In
```

**Request/Response Models**:
```dart
// Login Request
{
  "email": "string",
  "password": "string"
}

// Auth Response
{
  "user": {
    "id": "string",
    "email": "string",
    "displayName": "string?",
    "photoUrl": "string?",
    "isAnonymous": "boolean"
  },
  "accessToken": "string",
  "refreshToken": "string?",
  "expiresAt": "ISO8601 datetime"
}

// Refresh Token Request
{
  "refreshToken": "string"
}
```

### JournalRepository
**Location**: `lib/repositories/journal_repository.dart`

**Key Changes**:
- Replaced Firestore collection queries with REST calls
- Implemented polling-based stream watching (5-second intervals)
- All CRUD operations now HTTP-based

**API Endpoints Required**:
```
GET    /v1/journal/entries                   - List all entries (ordered by timestamp DESC)
GET    /v1/journal/entries/:entryId          - Get single entry
POST   /v1/journal/entries                   - Create new entry
PUT    /v1/journal/entries/:entryId          - Update entry
DELETE /v1/journal/entries/:entryId          - Delete entry
DELETE /v1/journal/entries?header:X-Delete-All=true - Delete all entries
GET    /v1/journal/entries/search            - Search by emotion/date
GET    /v1/journal/entries/date/:date        - Get entries for specific date
```

**Query Parameters**:
- `userId`: (optional) Filter by user ID

**JournalEntry Model**:
```dart
{
  "id": "string",
  "timestamp": "ISO8601 datetime",
  "emotionKey": "string", // 'happy', 'sad', 'angry', 'stressed', 'anxious', etc.
  "intensity": "number", // 1-5
  "trigger": "string",
  "situation": "string",
  "thought": "string",
  "response": "string",
  "exerciseId": "string?",
  "exerciseDone": "boolean",
  "afterIntensity": "number?",
  "afterEmotionKey": "string?",
  "usefulnessRating": "number?", // 1-5
  "easeRating": "number?", // 1-5
  "repeatPreference": "string?"
}
```

### GardenRepository
**Location**: `lib/repositories/garden_repository.dart`

**Key Changes**:
- Replaced Firestore subcollections with REST hierarchy
- Implemented polling-based stream watching
- Added helper methods for grouping and filtering

**API Endpoints Required**:
```
GET    /v1/garden/moments                          - List all moments
GET    /v1/garden/moments/:momentId                - Get single moment
POST   /v1/garden/moments                          - Create moment
PUT    /v1/garden/moments/:momentId                - Update moment
DELETE /v1/garden/moments/:momentId                - Delete moment
DELETE /v1/garden/moments?header:X-Delete-All=true - Delete all moments
GET    /v1/garden/moments/month/:monthKey          - Get moments for month (YYYY-MM)
GET    /v1/garden/moments/bed/:bedIndex            - Get moments for bed
```

**GardenMoment Model**:
```dart
{
  "id": "string",
  "entryId": "string",
  "monthKey": "string", // Format: "YYYY-MM"
  "bedIndex": "number",
  "slotIndex": "number",
  "plantedAt": "ISO8601 datetime",
  "appearanceVariant": "number" // 0-2
}
```

### ReflectionRepository
**Location**: `lib/repositories/reflection_repository.dart`

**Key Changes**:
- Replaced Cloud Functions with REST API
- Maintains fallback to local CBT model for resilience
- Added history and feedback endpoints

**API Endpoints Required**:
```
POST   /v1/reflection/generate                  - Generate AI reflection
GET    /v1/reflection/history                   - Get reflection history
POST   /v1/reflection/:reflectionId/feedback    - Save user feedback
POST   /v1/reflection/exercise                  - Get exercise recommendation
POST   /v1/reflection/safety-check              - Check for safety flags
GET    /v1/reflection/insights                  - Get AI insights
```

**Generate Reflection Request**:
```dart
{
  "emotionKey": "string",
  "intensity": "number", // 1-5
  "situation": "string?",
  "thought": "string?"
}
```

**AIReflection Response**:
```dart
{
  "possibleEmotions": ["string"],
  "possibleTrigger": "string",
  "intensifyingThought": "string",
  "reflectionQuestion": "string",
  "balancedThought": "string",
  "recommendedExercise": "string",
  "recommendationReason": "string",
  "microGoalPrompt": "string",
  "safetyFlag": "boolean",
  "safetyReason": "string?",
  "userFeedback": "string?",
  "recommendationsDismissed": "boolean"
}
```

### SharedGardenRepository
**Location**: `lib/repositories/shared_garden_repository.dart`

**Key Changes**:
- Replaced Firestore transactions with REST operations
- Implemented polling-based updates
- Garden codes: `MD-` prefix with 32 hex characters

**API Endpoints Required**:
```
POST   /v1/shared-garden/create                        - Create shared garden
POST   /v1/shared-garden/join                          - Join by invite code
GET    /v1/shared-garden/:gardenId                     - Get garden details
GET    /v1/shared-garden/user-garden                   - Get current user's garden
GET    /v1/shared-garden/:gardenId/moments             - Get garden moments
POST   /v1/shared-garden/:gardenId/plant               - Plant entry in garden
DELETE /v1/shared-garden/:gardenId/moments/:momentId   - Remove moment
DELETE /v1/shared-garden/:gardenId/my-moments          - Remove all user's moments
POST   /v1/shared-garden/:gardenId/leave               - Leave garden
POST   /v1/shared-garden/:gardenId/refresh-invite      - Generate new invite code
POST   /v1/shared-garden/:gardenId/moments/:momentId/interact - Water/sun interaction
```

**SharedGarden Model**:
```dart
{
  "id": "string",
  "code": "string", // Format: "MD-{32 hex chars}"
  "name": "string",
  "members": ["string"], // User IDs
  "memberNames": { "userId": "displayName" },
  "createdAt": "ISO8601 datetime"
}
```

**SharedMoment Model**:
```dart
{
  "id": "string",
  "gardenId": "string",
  "authorId": "string",
  "authorName": "string",
  "emotionKey": "string",
  "intensity": "number",
  "caption": "string",
  "slotIndex": "number",
  "bedIndex": "number",
  "monthKey": "string",
  "plantedAt": "ISO8601 datetime",
  "waterCount": "number",
  "sunCount": "number",
  "lastInteraction": "string?"
}
```

## HTTP Client Features

### Authentication Handling
```dart
HttpClient client = HttpClient();
client.setAuthToken('access_token_here');
client.setRefreshToken('refresh_token_here');
```

### Error Handling
```dart
try {
  var response = await client.get('/journal/entries');
} on ApiException catch (e) {
  print('Error: ${e.message}');
  print('Status: ${e.statusCode}');
  print('Response: ${e.response}');
}
```

### Request Headers
Automatically includes:
```
Content-Type: application/json
Accept: application/json
Authorization: Bearer {accessToken}
```

## Real-time Updates

**Important Change**: Firestore's real-time streams have been replaced with **polling-based streams** at 5-second intervals.

```dart
// All repository watch methods now use polling:
journalRepository.watchEntries(userId: uid).listen((entries) {
  // Updates every 5 seconds
});

gardenRepository.watchMoments(userId: uid).listen((moments) {
  // Updates every 5 seconds
});
```

**Backend Consideration**: For a production app, consider implementing WebSocket support or Server-Sent Events (SSE) instead of polling for better performance.

## Authentication Flow

1. **Initial Login**:
   ```dart
   var response = await authRepository.signInWithEmailPassword(email, password);
   // AuthResponse contains accessToken, refreshToken, expiresAt
   ```

2. **Token Refresh**:
   - AuthRepository automatically checks `shouldRefreshToken` property
   - Refresh happens when token is within 5 minutes of expiry
   - Manual refresh available via `refreshToken()` method

3. **Token Persistence**:
   The app expects the backend to implement token storage. Consider adding to MindraState:
   ```dart
   // Save tokens to secure storage (SharedPreferences or better)
   await _secureStorage.write(key: 'accessToken', value: response.accessToken);
   await _secureStorage.write(key: 'refreshToken', value: response.refreshToken);
   ```

## Remaining Firebase References

Some files still contain Firebase imports but are not in the main app flow:

1. **`lib/screens/login_view.dart`** - May have Firebase Auth references
2. **`lib/community/community_repository.dart`** - Community feature uses Cloud Functions
3. **`lib/community/community_widgets.dart`** - Community UI references
4. **`lib/core/garden_actions.dart`** - May reference Cloud Functions
5. **`test/` files** - Test files still use Firebase

**Action Required**: Update these files to use REST API equivalents or convert to mock implementations for testing.

## Migration Checklist

- [x] Remove Firebase dependencies from `pubspec.yaml`
- [x] Create HTTP client infrastructure
- [x] Convert all repositories to REST API
- [x] Update state management (MindraState)
- [x] Remove Firebase initialization from main.dart
- [ ] Backend: Implement all required API endpoints
- [ ] Backend: Setup authentication token system
- [ ] Update login/register flows in screens
- [ ] Update community features to use REST API
- [ ] Update tests to use mocked HTTP client
- [ ] Add secure token storage implementation
- [ ] Consider WebSocket/SSE for real-time instead of polling
- [ ] Add comprehensive error handling and user feedback

## API Error Responses

**Expected error response format**:
```json
{
  "message": "Error description",
  "code": "ERROR_CODE",
  "details": {}
}
```

The HttpClient will extract the `message` field for exceptions.

## Configuration

To change API base URL:

Edit `lib/core/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'https://your-api-url.com';
  // ... rest of configuration
}
```

## Testing

For testing, mock the HttpClient:

```dart
class MockHttpClient extends HttpClient {
  @override
  Future<dynamic> get(String endpoint, ...) async {
    // Return mock data
  }
}
```

Then inject into repositories:
```dart
var repository = JournalRepository(httpClient: mockClient);
```

## Performance Considerations

1. **Polling Interval**: Currently 5 seconds. Adjust in each repository's `watchXxx()` methods.
2. **Request Timeout**: 30 seconds (configurable in `ApiConfig`)
3. **Connection Timeout**: 10 seconds (configurable in `ApiConfig`)

## Security Considerations

1. **Token Storage**: Use secure storage (not SharedPreferences plain text)
2. **HTTPS Only**: Ensure all API calls use HTTPS
3. **Token Expiry**: Implement automatic refresh
4. **CORS**: Configure backend CORS for Flutter web platform
5. **Rate Limiting**: Implement rate limiting for auth endpoints
6. **Input Validation**: Validate all user inputs before API calls

## Next Steps

1. Implement backend API following the endpoint contracts above
2. Update community features to REST API
3. Add secure token storage
4. Update UI components that reference Firebase
5. Implement WebSocket support (optional but recommended)
6. Add comprehensive integration tests
7. Deploy and monitor API performance

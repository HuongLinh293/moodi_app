# Quick Start - REST API Integration

## What Changed?

The app now uses **HTTP REST API** instead of Firebase. Everything works the same from the app's perspective, but communication is through REST endpoints.

## For Developers

### 1. Configure API Base URL

Edit `lib/core/api_config.dart`:
```dart
static const String baseUrl = 'https://your-api-url.com';
```

### 2. Update Repositories (if needed)

All repositories are in `lib/repositories/`:
- `auth_repository.dart` - Authentication
- `journal_repository.dart` - Journal entries
- `garden_repository.dart` - Garden moments
- `reflection_repository.dart` - AI reflections
- `shared_garden_repository.dart` - Shared gardens

Each uses the `HttpClient` singleton automatically.

### 3. Example: Make an API Call

```dart
// Get all journal entries
var entries = await journalRepository.fetchEntries(userId: userId);

// The HttpClient handles:
// ✅ URL building
// ✅ Authorization headers
// ✅ JSON serialization
// ✅ Error handling
// ✅ Token refresh
```

### 4. Real-time Updates

All `watch*` methods now use polling (5-second intervals):

```dart
// This polls every 5 seconds instead of Firebase subscriptions
journalRepository.watchEntries(userId: userId).listen((entries) {
  print('Updated entries: $entries');
});
```

## For Backend Team

### Setup Required

1. **Base URL**: `https://api.moodi.app/v1`
2. **Implement 33 endpoints** (see `API_INTEGRATION_GUIDE.md`)
3. **Auth tokens**: Return `accessToken`, `refreshToken`, `expiresAt` in responses
4. **CORS**: Enable CORS for Flutter web platform
5. **Errors**: Return `{ "message": "error description" }` in error responses

### Endpoint Summary

```
Authentication (7)    - /auth/*
Journal (6)          - /journal/entries/*
Garden (6)           - /garden/moments/*
Reflection (6)       - /reflection/*
Shared Garden (8)    - /shared-garden/*
```

### Example Response Format

```json
{
  "user": {
    "id": "abc123",
    "email": "user@example.com",
    "displayName": "John",
    "isAnonymous": false
  },
  "accessToken": "eyJhbGc...",
  "refreshToken": "refresh...",
  "expiresAt": "2024-10-20T15:30:00Z"
}
```

## Common Tasks

### Add Authentication to Request

Automatically handled by HttpClient:
```dart
client.setAuthToken('access_token_here');
```

### Handle Errors

```dart
try {
  await journalRepository.saveEntry(entry);
} on ApiException catch (e) {
  print('Error: ${e.message}');
  print('Status: ${e.statusCode}');
}
```

### Search/Filter

```dart
// Get entries by emotion
var stressed = await journalRepository.searchByEmotion('stressed');

// Get entries for specific date
var today = await journalRepository.fetchEntriesForDate(DateTime.now());
```

### Real-time Polling

Adjust polling interval in any `watchXxx()` method:

```dart
// Change from 5 seconds to 10 seconds
const pollInterval = Duration(seconds: 10);

Stream.periodic(pollInterval, (_) async {
  // fetch data
});
```

## Testing

### With Mock API

```dart
var mockClient = MockHttpClient();
var repo = JournalRepository(httpClient: mockClient);
// Test with mock responses
```

### Integration Tests

```dart
// Use real API for integration testing
var repo = JournalRepository(); // Uses real HttpClient
var entries = await repo.fetchEntries(userId: testUserId);
expect(entries, isNotEmpty);
```

## Troubleshooting

### "API Exception: Request timeout"
- Increase timeout in `lib/core/api_config.dart`
- Check network connectivity
- Verify backend is running

### "Unauthorized" Errors
- Token may be expired (auto-refresh should handle)
- Check `accessToken` is being sent correctly
- Verify token refresh endpoint works

### Missing Real-time Updates
- Polling interval may be too long
- Adjust in repository `watchXxx()` methods
- Consider WebSocket for better performance

### Still Seeing Firebase Errors
- Some files (community features) still reference Firebase
- These are non-critical and can be updated separately
- See `MIGRATION_SUMMARY.md` for priority list

## File Structure

```
lib/
├── core/
│   ├── api_config.dart          ← API endpoints
│   └── http_client.dart         ← HTTP client (singleton)
├── repositories/
│   ├── auth_repository.dart     ← Auth (REST)
│   ├── journal_repository.dart  ← Entries (REST)
│   ├── garden_repository.dart   ← Moments (REST)
│   ├── reflection_repository.dart ← AI (REST)
│   └── shared_garden_repository.dart ← Shared (REST)
├── state/
│   └── mindra_state.dart        ← App state
└── main.dart                     ← App entry point
```

## Next Steps

1. ✅ Frontend: Complete (you're reading this!)
2. ⏳ Backend: Implement API endpoints
3. ⏳ Testing: Integration testing with API
4. ⏳ Community: Update remaining Firebase references
5. ⏳ Deploy: Gradual rollout

## Resources

- `API_INTEGRATION_GUIDE.md` - Full endpoint specifications
- `MIGRATION_SUMMARY.md` - Migration details & checklist
- `lib/repositories/*.dart` - Reference implementations
- `lib/core/http_client.dart` - HTTP client usage

## Questions?

See the detailed guides in the project root:
- API specifications: `API_INTEGRATION_GUIDE.md`
- Migration details: `MIGRATION_SUMMARY.md`
- This quick reference: `QUICK_START.md`

---

**App is ready for REST API!** 🚀

Just implement the backend endpoints and you're good to go.

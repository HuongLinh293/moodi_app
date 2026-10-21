import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindra/community/community_repository.dart';
import 'package:mindra/core/http_client.dart';
import 'package:mindra/core/token_store.dart';
import 'package:mindra/repositories/auth_repository.dart';

Map<String, dynamic> authPayload(String access, String refresh) => {
  'user': {'id': 'alice', 'email': 'a@example.invalid'},
  'accessToken': access,
  'refreshToken': refresh,
  'expiresAt': 1792540800,
};

void main() {
  test('login persists only the refresh token; logout clears it', () async {
    final store = MemoryTokenStore();
    final client = HttpClient.withClient(
      MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(jsonEncode(authPayload('a1', 'r1')), 200);
        }
        return http.Response('', 204);
      }),
    );
    final repo = AuthRepository(httpClient: client, tokenStore: store);
    await repo.signInWithEmailPassword('a@example.invalid', 'secret-pass');
    await Future<void>.delayed(Duration.zero);
    expect(store.session!.refreshToken, 'r1');
    expect(jsonEncode(store.session!.user), isNot(contains('a1')));
    await repo.signOut();
    expect(store.session, isNull);
    client.dispose();
  });

  test('restoreSession exchanges the stored token and rotates it', () async {
    final store = MemoryTokenStore()
      ..session = const StoredSession(
        refreshToken: 'r-old',
        user: {'id': 'alice', 'email': 'a@example.invalid'},
      );
    final client = HttpClient.withClient(
      MockClient((request) async {
        expect(request.url.path, '/api/auth/refresh-token');
        expect(jsonDecode(request.body)['refreshToken'], 'r-old');
        return http.Response(jsonEncode(authPayload('a2', 'r-new')), 200);
      }),
    );
    final repo = AuthRepository(httpClient: client, tokenStore: store);
    expect(await repo.restoreSession(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(repo.currentUserId, 'alice');
    expect(client.authToken, 'a2');
    expect(store.session!.refreshToken, 'r-new');
    client.dispose();
  });

  test('rejected stored token is wiped; network failure keeps it', () async {
    for (final (status, kept) in [(401, false), (503, true)]) {
      final store = MemoryTokenStore()
        ..session = const StoredSession(refreshToken: 'r', user: {'id': 'a'});
      final client = HttpClient.withClient(
        MockClient((_) async => http.Response('{}', status)),
      );
      final repo = AuthRepository(httpClient: client, tokenStore: store);
      expect(await repo.restoreSession(), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(store.session != null, kept, reason: 'status $status');
      client.dispose();
    }
  });

  test('concurrent 401s share one refresh and each request retries', () async {
    var refreshes = 0;
    final client = HttpClient.withClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/auth/login') {
          return http.Response(jsonEncode(authPayload('expired', 'r1')), 200);
        }
        if (path == '/api/auth/refresh-token') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(jsonEncode(authPayload('fresh', 'r2')), 200);
        }
        return request.headers['Authorization'] == 'Bearer fresh'
            ? http.Response('[]', 200)
            : http.Response('{"message":"Unauthorized"}', 401);
      }),
    );
    final repo = AuthRepository(
      httpClient: client,
      tokenStore: MemoryTokenStore(),
    );
    final events = <AuthUser?>[];
    final sub = repo.authStateChanges.listen(events.add);
    await repo.signInWithEmailPassword('a@example.invalid', 'secret-pass');
    final results = await Future.wait([
      client.get('/entries'),
      client.get('/moments'),
      client.get('/entries'),
    ]);
    expect(results, everyElement(isEmpty));
    expect(refreshes, 1);
    // Refresh chỉ thay token: không phát sự kiện đổi user (không xoá dữ liệu).
    expect(events.length, 1);
    await sub.cancel();
    client.dispose();
  });

  test(
    'Community calls the Nest gateway and keeps the server error code',
    () async {
      late Map<String, dynamic> sent;
      final client = HttpClient.withClient(
        MockClient((request) async {
          expect(request.url.path, '/api/community');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'statusCode': 409,
                'code': 'already-exists',
                'message': 'Yêu cầu đã được sử dụng cho nội dung khác.',
              }),
            ),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..setAuthToken('t');
      final repo = CommunityRepository(uid: 'alice', httpClient: client);
      await expectLater(
        repo.mutate('comment', {'space': 'public', 'postId': 'p', 'text': 'x'}),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'already-exists'),
        ),
      );
      expect(sent['action'], 'comment');
      expect(sent['requestId'], hasLength(40));
      client.dispose();
    },
  );
}

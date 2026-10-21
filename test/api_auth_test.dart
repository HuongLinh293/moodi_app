import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindra/core/http_client.dart';
import 'package:mindra/models/journal_entry.dart';
import 'package:mindra/repositories/auth_repository.dart';
import 'package:mindra/repositories/journal_repository.dart';

void main() {
  test(
    'Nest auth response accepts epoch seconds and emits login/logout',
    () async {
      final payload = {
        'user': {
          'id': 'alice',
          'email': 'a@example.invalid',
          'avatar': 'avatar.jpg',
        },
        'accessToken': 'test-access',
        'refreshToken': 'test-refresh',
        'expiresAt': 1792540800,
      };
      final client = HttpClient.withClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/register') {
            final data = jsonDecode(request.body) as Map;
            expect(data['username'], isNotEmpty);
            expect(data['displayName'], 'Linh');
            expect(data['email'], 'a@example.invalid');
            return http.Response(jsonEncode(payload), 201);
          }
          expect(request.url.path, '/api/auth/logout');
          expect(request.headers['Authorization'], 'Bearer test-access');
          return http.Response('{}', 200);
        }),
      );
      final repo = AuthRepository(httpClient: client);
      final events = <AuthUser?>[];
      final subscription = repo.authStateChanges.listen(events.add);
      final result = await repo.registerWithEmailPassword(
        'a@example.invalid',
        'test-password',
        displayName: 'Linh',
      );
      expect(result!.expiresAt.millisecondsSinceEpoch, 1792540800000);
      expect(result.user.photoUrl, 'avatar.jpg');
      expect(events.single!.id, 'alice');
      expect(client.authToken, 'test-access');
      await repo.signOut();
      expect(events.last, isNull);
      expect(client.authToken, isNull);
      await subscription.cancel();
      client.dispose();
    },
  );

  test(
    'journal sync sends UTC timestamps and reads them back as local',
    () async {
      final local = DateTime(2026, 10, 20, 8);
      late String sentTimestamp;
      final client = HttpClient.withClient(
        MockClient((request) async {
          if (request.method == 'PUT') {
            expect(request.url.path, '/api/entries/entry-1');
            sentTimestamp = (jsonDecode(request.body) as Map)['timestamp'];
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'entry-1',
                'timestamp': sentTimestamp,
                'emotionKey': 'sad',
              },
            ]),
            200,
          );
        }),
      );
      final repo = JournalRepository(httpClient: client);
      await repo.saveEntry(
        JournalEntry(
          id: 'entry-1',
          timestamp: local,
          emotionKey: 'sad',
          intensity: 4,
          trigger: 'work',
          situation: '',
          thought: '',
          response: '',
        ),
        userId: 'alice',
      );
      expect(sentTimestamp, endsWith('Z'));
      final entries = await repo.fetchEntries(userId: 'alice');
      expect(entries.single.timestamp.isUtc, isFalse);
      expect(entries.single.timestamp, local);
      client.dispose();
    },
  );

  test('Nest validation errors surface every message', () async {
    final client = HttpClient.withClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': ['intensity must not be greater than 5', 'x'],
            'statusCode': 400,
          }),
          400,
        ),
      ),
    );
    await expectLater(
      client.put('/entries/entry-1', body: {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'intensity must not be greater than 5; x',
        ),
      ),
    );
    client.dispose();
  });
}

import 'dart:async';

import 'package:mindra/core/http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mindra/community/community_repository.dart';
import 'package:mindra/community/community_widgets.dart';
import 'package:mindra/community/community_posts.dart';
import 'package:mindra/community/community_people.dart';
import 'package:mindra/community/community_groups.dart';

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));
CommunityRepository repository(Future<Json> Function(Json) handler) =>
    CommunityRepository(
      uid: 'alice',
      sessionValid: () => true,
      transport: handler,
    );
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('friend codes accept pasted display formatting', () {
    expect(normalizeCommunityHandleInput(' @ABCD 1234-EF56 '), 'abcd1234ef56');
    expect(formatCommunityHandle('abcd1234ef56'), 'ABCD 1234 EF56');
  });
  testWidgets('empty group exposes a composer action', (tester) async {
    final repo = repository((payload) async {
      if (payload['action'] == 'feed') return {'items': <Json>[]};
      throw StateError('Unexpected action: ${payload['action']}');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityGroupPage(
          repo: repo,
          space: 'family',
          name: 'Gia Đình nhỏ',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Viết trong nhóm'), findsOneWidget);
    await tester.tap(find.text('Viết trong nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng tại: Gia Đình nhỏ'), findsOneWidget);
    expect(find.text('Đăng vào nhóm'), findsOneWidget);
  });
  test(
    'backend errors propagate instead of silently becoming demo successes',
    () async {
      for (final code in [
        'unavailable',
        'permission-denied',
        'unauthenticated',
        'invalid-argument',
      ]) {
        var calls = 0;
        final repo = repository((_) async {
          calls++;
          throw ApiException(code: code, message: 'server error');
        });
        for (var i = 0; i < 2; i++) {
          await expectLater(
            repo.mutate('sendMessage', {'target': 'bob', 'text': 'hello'}),
            throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
          );
        }
        expect(calls, 2);
      }
    },
  );
  testWidgets(
    'pagination retry keeps loaded items and repeats the failed cursor',
    (tester) async {
      var fail = true;
      final cursors = <Json?>[];
      await tester.pumpWidget(
        app(
          CommunityList(
            load: (cursor) async {
              cursors.add(cursor);
              if (cursor != null && fail) {
                throw ApiException(code: 'unavailable', message: 'Mất kết nối');
              }
              return cursor == null
                  ? {
                      'items': [
                        {'id': '1', 'text': 'Bài đã tải'},
                      ],
                      'cursor': {'id': 'next'},
                    }
                  : {
                      'items': [
                        {'id': '2', 'text': 'Bài tiếp theo'},
                      ],
                    };
            },
            builder: (p, _) => Text(p['text']),
            emptyTitle: 'Empty',
            emptyDescription: '',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();
      expect(find.text('Bài đã tải'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Bài đã tải'), findsOneWidget);
      expect(find.text('Bài tiếp theo'), findsOneWidget);
      expect(cursors, [
        null,
        {'id': 'next'},
        {'id': 'next'},
      ]);
    },
  );
  testWidgets('revoked access clears loaded private content', (tester) async {
    var revoked = false;
    final key = GlobalKey<CommunityListState>();
    await tester.pumpWidget(
      app(
        CommunityList(
          key: key,
          load: (_) async {
            if (revoked) {
              throw ApiException(
                code: 'permission-denied',
                message: 'Không còn quyền',
              );
            }
            return {
              'items': [
                {'id': 'private', 'text': 'Riêng tư'},
              ],
            };
          },
          builder: (p, _) => Text(p['text']),
          emptyTitle: 'Empty',
          emptyDescription: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    revoked = true;
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Riêng tư'), findsNothing);
  });
  testWidgets('react updates one post without reloading its feed', (
    tester,
  ) async {
    var loads = 0;
    final repo = repository((d) async {
      if (d['action'] == 'feed') {
        loads++;
        return {
          'items': [
            {
              'id': 'post',
              'author': 'bob',
              'authorName': 'Minh',
              'text': 'Khoảnh khắc',
              'mood': '',
              'intent': '',
              'imagePath': '',
              'likes': 3,
              'liked': false,
              'commentsOpen': true,
              'createdAt': 1700000000000,
            },
          ],
        };
      }
      if (d['action'] == 'react') return {'likes': 4, 'liked': true};
      throw StateError('Unexpected ${d['action']}');
    });
    await tester.pumpWidget(app(CommunityFeed(repo: repo)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đồng cảm · 3'));
    await tester.tap(find.text('Đồng cảm · 3'));
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('Đồng cảm · 4'), findsOneWidget);
  });
  testWidgets(
    'direct message keeps retry ID, disables draft and renews ID after success',
    (tester) async {
      final sent = <Json>[];
      Completer<Json>? pending;
      final repo = repository((d) async {
        if (d['action'] == 'messages') {
          return {
            'items': [],
            'relation': {'status': 'accepted', 'blockedBy': []},
          };
        }
        if (d['action'] == 'sendMessage') {
          sent.add(d);
          pending = Completer<Json>();
          return pending!.future;
        }
        throw StateError('Unexpected');
      });
      await tester.pumpWidget(
        app(CommunityChatPage(repo: repo, target: 'bob', name: 'Minh')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Chào bạn');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      pending!.completeError(
        ApiException(code: 'unavailable', message: 'Mất kết nối'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chào bạn'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pump();
      expect(sent[0]['requestId'], sent[1]['requestId']);
      pending!.complete({'id': 'message'});
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'Chào bạn');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pump();
      expect(sent[2]['requestId'], isNot(sent[1]['requestId']));
      await tester.pumpWidget(const SizedBox.shrink());
      pending!.complete({'id': 'message2'});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('inbox displays preview and unread marker', (tester) async {
    final repo = repository(
      (_) async => {
        'items': [
          {
            'status': 'accepted',
            'hasMessages': true,
            'blockedBy': [],
            'profile': {'id': 'bob', 'name': 'Minh'},
            'preview': 'Hẹn gặp bạn',
            'lastMessageAt': 1700000000000,
            'unread': true,
          },
        ],
      },
    );
    await tester.pumpWidget(
      app(CommunityPeoplePage(repo: repo, messages: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hẹn gặp bạn'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Có tin nhắn chưa đọc')),
      findsOneWidget,
    );
  });
  for (final action in [
    'Đóng nhóm',
    'Chuyển quyền chủ nhóm',
    'Mời rời nhóm',
    'Thu hồi',
  ]) {
    testWidgets('group confirmation describes $action', (tester) async {
      final repo = repository(
        (_) async => {
          'group': {'name': 'Bạn thân', 'owner': 'alice', 'description': ''},
          'members': [
            {'id': 'alice', 'name': 'Linh'},
            {'id': 'bob', 'name': 'Minh'},
          ],
          'invited': [
            {'id': 'carol', 'name': 'An'},
          ],
        },
      );
      await tester.pumpWidget(
        app(CommunityGroupSettings(repo: repo, space: 'group')),
      );
      await tester.pumpAndSettle();
      if (action == 'Chuyển quyền chủ nhóm' || action == 'Mời rời nhóm') {
        await tester.tap(find.byTooltip('Quản lý thành viên'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final title = (dialog.title as Text).data!;
      final body = (dialog.content as Text).data!;
      expect(body, contains('nhóm'));
      expect(
        title,
        contains(
          action == 'Đóng nhóm'
              ? 'Bạn thân'
              : action == 'Thu hồi'
              ? 'An'
              : 'Minh',
        ),
      );
      expect(
        find.text('Thao tác này sẽ thay đổi quyền tham gia hoặc quản lý nhóm.'),
        findsNothing,
      );
    });
  }
}

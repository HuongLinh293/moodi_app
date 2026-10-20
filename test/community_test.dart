import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mindra/community/community_repository.dart';
import 'package:mindra/community/community_view.dart';
import 'package:mindra/community/community_posts.dart';
import 'package:mindra/community/community_people.dart';
import 'package:mindra/core/theme/theme.dart';
import 'package:mindra/state/mindra_state.dart';

class FakeCommunity extends CommunityRepository {
  FakeCommunity() : super(uid: 'alice');
  final calls = <Json>[];
  bool registered = true, failSend = false, failFeed = false;
  Json get post => {
    'id': 'post1',
    'author': 'bob',
    'authorName': 'Minh',
    'text': 'Hôm nay mình đã hoàn thành bài thuyết trình. Vẫn còn run, nhưng vui vì đã thử.',
    'mood': 'Vui vẻ',
    'intent': 'Chia sẻ chuyện vui',
    'imagePath': '',
    'likes': 2,
    'liked': false,
    'commentsOpen': true,
    'createdAt': 1,
  };
  @override
  bool get validSession => true;
  @override
  Future<Json> call(String action, [Json data = const {}]) async {
    calls.add({'action': action, ...data});
    if (action == 'bootstrap') {
      return {
        'me': registered
            ? {'id': 'alice', 'name': 'Linh', 'handle': 'abc123abc123'}
            : null,
        'admin': false,
      };
    }
    if (action == 'feed') {
      if (failFeed) throw StateError('Mất kết nối');
      return {
        'items': [post],
      };
    }
    if (action == 'groups') return {'items': [], 'invites': []};
    if (action == 'createPost' || action == 'sendMessage') {
      if (failSend) throw StateError('Gửi chưa thành công');
      return {'id': 'created'};
    }
    if (action == 'messages') {
      return {
        'items': [],
        'relation': {'status': 'accepted', 'blockedBy': []},
      };
    }
    if (action == 'connections') {
      return {
        'items': [
          {
            'status': 'pending',
            'requestedBy': 'bob',
            'blockedBy': [],
            'hasMessages': false,
            'profile': {'id': 'bob', 'name': 'Minh'},
          },
        ],
      };
    }
    if (action == 'profile') {
      return {
        'profile': {
          'id': 'bob',
          'name': 'Minh',
          'bio': '',
          'handle': 'def123def123',
        },
        'relation': {
          'status': 'pending',
          'requestedBy': 'bob',
          'blockedBy': [],
          'hasMessages': false,
        },
      };
    }
    if (action == 'post') return {'post': post};
    if (action == 'comments') return {'items': []};
    if (action == 'friendship') return {};
    throw StateError('Unexpected action: $action');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (Platform.environment['COMMUNITY_CAPTURE'] == '1') {
      final font = ByteData.sublistView(
        await File('/tmp/moodi-community-font.ttf').readAsBytes(),
      );
      final theme = AppTheme.lightTheme.textTheme;
      final names = [
        theme.titleLarge,
        theme.bodyLarge,
        theme.bodyMedium,
        theme.labelLarge,
        theme.headlineSmall,
      ].map((s) => s?.fontFamily).whereType<String>().toSet();
      for (final name in names) {
        await (FontLoader(name)..addFont(Future.value(font))).load();
      }
      final icons = Platform.environment['COMMUNITY_ICONS'];
      if (icons != null) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(
                ByteData.sublistView(await File(icons).readAsBytes()),
              ),
            ))
            .load();
      }
    }
  });
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('community feed and group switch fit ${width.toInt()}pt', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = MindraState();
      addTearDown(state.dispose);
      final repo = FakeCommunity();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: const Color(0xFFF8F3EA),
                child: CommunityView(state: state, repository: repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Góc sẻ chia'), findsOneWidget);
      expect(find.text('Chia sẻ chuyện vui'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 375 && Platform.environment['COMMUNITY_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/moodi-community-feed.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Nhóm của tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo nhóm riêng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('new community user creates a separate nickname', (tester) async {
    final state = MindraState();
    addTearDown(state.dispose);
    final repo = FakeCommunity()..registered = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CommunityView(state: state, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tạo biệt danh để bắt đầu'), findsOneWidget);
    expect(repo.calls.where((c) => c['action'] == 'feed'), isEmpty);
  });
  testWidgets(
    'failed post retains draft and retry uses same request ID and audience',
    (tester) async {
      final repo = FakeCommunity()..failSend = true;
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CommunityComposer(
            repo: repo,
            destination: 'Bạn thân',
            scope: const {'space': 'private-group'},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Một chuyện riêng');
      await tester.ensureVisible(find.text('Đăng vào nhóm'));
      await tester.tap(find.text('Đăng vào nhóm'));
      await tester.pumpAndSettle();
      expect(find.text('Gửi chưa thành công'), findsOneWidget);
      expect(find.text('Một chuyện riêng'), findsOneWidget);
      await tester.ensureVisible(find.text('Đăng vào nhóm'));
      await tester.tap(find.text('Đăng vào nhóm'));
      await tester.pumpAndSettle();
      final calls = repo.calls
          .where((c) => c['action'] == 'createPost')
          .toList();
      expect(calls, hasLength(2));
      expect(calls[0]['requestId'], calls[1]['requestId']);
      expect(calls[0]['space'], 'private-group');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('incoming friend request can be accepted from profile', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CommunityProfilePage(repo: repo, target: 'bob'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chấp nhận kết bạn'));
    await tester.pumpAndSettle();
    expect(
      repo.calls.any(
        (c) =>
            c['action'] == 'friendship' &&
            c['kind'] == 'accept' &&
            c['target'] == 'bob',
      ),
      isTrue,
    );
  });
  testWidgets('feed failure can retry without displaying a fake empty feed', (
    tester,
  ) async {
    final state = MindraState();
    addTearDown(state.dispose);
    final repo = FakeCommunity()..failFeed = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CommunityView(state: state, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    repo.failFeed = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Minh'), findsOneWidget);
  });
  test('repository rejects stale session before reaching Firebase', () async {
    final repo = CommunityRepository(uid: 'alice', sessionValid: () => false);
    await expectLater(
      repo.call('messages', {'target': 'bob'}),
      throwsStateError,
    );
  });
  test(
    'late response is rejected after account switches A to B to A',
    () async {
      var revision = 0;
      final pending = Completer<Json>();
      final repo = CommunityRepository(
        uid: 'alice',
        sessionValid: () => revision == 0,
        transport: (_) => pending.future,
      );
      final response = repo.call('messages', {'target': 'bob'});
      final assertion = expectLater(response, throwsStateError);
      revision = 2;
      pending.complete({
        'items': [
          {'text': 'private'},
        ],
      });
      await assertion;
    },
  );
  testWidgets('large text keeps community actions reachable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = MindraState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: CommunityView(state: state, repository: FakeCommunity()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../state/mindra_state.dart';
import 'community_repository.dart';
import 'community_widgets.dart';
import 'community_posts.dart';
import 'community_groups.dart';
import 'community_people.dart';

class CommunityView extends StatefulWidget {
  const CommunityView({super.key, required this.state, this.repository});
  final MindraState state;
  final CommunityRepository? repository;
  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  late final CommunityRepository repo;
  Json? bootstrap;
  String? error;
  int section = 0;
  Timer? updates;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    final revision = widget.state.sessionRevision;
    final userUid = widget.state.currentUserId;
    repo =
        widget.repository ??
        CommunityRepository(
          uid: userUid,
          sessionValid: () =>
              widget.state.sessionRevision == revision &&
              (userUid != null && widget.state.currentUserId == userUid),
        );
    load();
    updates = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        load();
      }
    });
  }

  @override
  void dispose() {
    updates?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    try {
      final d = await repo.call('bootstrap');
      if (mounted) {
        setState(() {
          bootstrap = d;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = CommunityRepository.error(e));
    } finally {
      loading = false;
    }
  }

  Future<void> register() async {
    await communityPush(
      context,
      CommunityForm(
        title: 'Một góc để là chính bạn',
        button: 'Tạo hồ sơ cộng đồng',
        description: 'Chọn biệt danh để mọi người nhận ra bạn. Email và nhật ký riêng không hiển thị. Hãy tôn trọng người khác; bạn có thể chặn và báo cáo nội dung không phù hợp.',
        fields: [
          (
            key: 'name',
            label: 'Biệt danh',
            max: 40,
            initial: widget.state.userName.isNotEmpty
                ? widget.state.userName
                : 'Linh',
          ),
          const (
            key: 'bio',
            label: 'Giới thiệu ngắn (tùy chọn)',
            max: 160,
            initial: '',
          ),
        ],
        submit: (v) async {
          await repo.mutate('saveProfile', v);
        },
      ),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ListView(
        children: [
          CommunityEmpty(
            'Chưa kết nối được Góc sẻ chia',
            error!,
            action: OutlinedButton(
              onPressed: load,
              child: const Text('Thử lại'),
            ),
          ),
        ],
      );
    }
    if (bootstrap == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bootstrap!['me'] == null) {
      return ListView(
        children: [
          CommunityEmpty(
            'Có những câu chuyện đáng được lắng nghe',
            'Chia sẻ một chút hôm nay, tìm người đồng cảm hoặc tạo một nhóm riêng cho những người bạn tin.',
            icon: Icons.forum_outlined,
            action: FilledButton(
              onPressed: register,
              child: const Text('Tạo biệt danh để bắt đầu'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Góc sẻ chia',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bạn bè',
                onPressed: () =>
                    communityPush(context, CommunityPeoplePage(repo: repo)),
                icon: Badge(
                  isLabelVisible: (bootstrap!['pending'] as int? ?? 0) > 0,
                  label: Text('${bootstrap!['pending'] ?? 0}'),
                  child: const Icon(Icons.people_outline, size: 22),
                ),
              ),
              IconButton(
                tooltip: 'Tin nhắn',
                onPressed: () => communityPush(
                  context,
                  CommunityPeoplePage(repo: repo, messages: true),
                ),
                icon: Badge(
                  isLabelVisible: (bootstrap!['unread'] as int? ?? 0) > 0,
                  label: Text('${bootstrap!['unread'] ?? 0}'),
                  child: const Icon(Icons.chat_bubble_outline, size: 22),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Hồ sơ cộng đồng',
                onSelected: (v) async {
                  if (v == 'profile') {
                    await communityPush(
                      context,
                      CommunityProfilePage(repo: repo, target: repo.uid!),
                    );
                  } else {
                    await communityPush(
                      context,
                      CommunityModerationPage(repo: repo),
                    );
                  }
                  load();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('Hồ sơ của tôi'),
                  ),
                  if (bootstrap!['admin'] == true)
                    const PopupMenuItem(
                      value: 'moderation',
                      child: Text('Xử lý báo cáo'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final item in [
                  (0, 'Chung', Icons.public),
                  (1, 'Nhóm của tôi', Icons.lock_outline),
                ])
                  Expanded(
                    child: Semantics(
                      selected: section == item.$1,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: section == item.$1
                              ? AppColors.cream
                              : Colors.transparent,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => setState(() => section = item.$1),
                        icon: Icon(item.$3, size: 18),
                        label: Text(
                          item.$2,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              section == 0
                  ? CommunityFeed(repo: repo)
                  : CommunityGroups(repo: repo),
              // FAB for quick compose — always accessible while scrolling
              if (section == 0)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'community_compose_fab',
                    backgroundColor: AppColors.ink,
                    foregroundColor: AppColors.cream,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Chia sẻ'),
                    onPressed: () async {
                      await communityPush(
                        context,
                        CommunityComposer(
                          repo: repo,
                          destination: 'Cộng đồng chung',
                          scope: const {'space': 'public'},
                        ),
                      );
                      load();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommunityModerationPage extends StatelessWidget {
  const CommunityModerationPage({super.key, required this.repo});
  final CommunityRepository repo;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xử lý báo cáo')),
    body: SafeArea(
      child: CommunityList(
        load: (cursor) => repo.call('reports', {'cursor': ?cursor}),
        emptyTitle: 'Chưa có báo cáo',
        emptyDescription: 'Các báo cáo cần xử lý sẽ xuất hiện ở đây.',
        builder: (r, refresh) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['reason'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if ((r['evidence'] as String? ?? '').isNotEmpty)
                  Text(r['evidence']),
                Text(
                  'Trạng thái: ${r['status'] == 'open' ? 'Chờ xử lý' : 'Đã xử lý'}',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final action in [
                      ('dismiss', 'Bỏ qua'),
                      ('remove', 'Gỡ nội dung'),
                      ('suspend', 'Khóa tài khoản'),
                      ('restore', 'Mở khóa'),
                    ])
                      TextButton(
                        onPressed: () async {
                          if (!await communityConfirm(
                            context,
                            action.$2,
                            'Thao tác quản trị sẽ được ghi nhận.',
                          )) {
                            return;
                          }
                          try {
                            await repo.mutate('moderate', {
                              'reportId': r['id'],
                              'kind': action.$1,
                            });
                            refresh();
                          } catch (e) {
                            if (context.mounted) communityError(context, e);
                          }
                        },
                        child: Text(action.$2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

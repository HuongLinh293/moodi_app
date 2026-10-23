import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';
import 'community_repository.dart';
import 'community_widgets.dart';
import 'community_posts.dart';
import 'community_groups.dart';
import 'community_people.dart';
import 'community_notifications.dart';

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
  final feedKey = GlobalKey<CommunityFeedState>();

  String get formattedDate {
    const days = [
      'THỨ HAI',
      'THỨ BA',
      'THỨ TƯ',
      'THỨ NĂM',
      'THỨ SÁU',
      'THỨ BẢY',
      'CHỦ NHẬT',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} · ${DateFormat("dd 'THÁNG' MM, yyyy").format(now)}';
  }

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
          widget.state.currentTab == 2 &&
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

  Future<void> compose() async {
    await communityPush(
      context,
      CommunityComposer(
        repo: repo,
        destination: 'Cộng đồng chung',
        scope: const {'space': 'public'},
      ),
    );
    if (!mounted) return;
    feedKey.currentState?.refresh();
    load();
  }

  Widget _emptyActions() {
    return Column(
      children: [
        OutlinedButton(
          onPressed: () =>
              communityPush(context, CommunityPeoplePage(repo: repo)),
          child: const Text('Tìm người đồng cảm'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _createGroup,
          child: const Text('Tạo nhóm riêng'),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    final requestId = repo.newRequestId();
    String? groupId;
    var name = '';
    await communityPush(
      context,
      CommunityForm(
        title: 'Tạo nhóm riêng',
        button: 'Tạo nhóm',
        description: 'Chỉ người được mời mới vào được. Nhật ký riêng không đưa vào nhóm.',
        fields: const [
          (key: 'name', label: 'Tên nhóm', max: 60, initial: ''),
          (
            key: 'description',
            label: 'Vài dòng về nhóm',
            max: 240,
            initial: '',
          ),
        ],
        submit: (values) async {
          name = values['name'] ?? '';
          groupId = (await repo.mutate(
            'createGroup',
            values,
            requestId: requestId,
          ))['id'];
        },
      ),
    );
    if (!mounted || groupId == null) return;
    await communityPush(
      context,
      CommunityGroupPage(repo: repo, space: groupId!, name: name),
    );
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
    final pending = bootstrap!['pending'] as int? ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(formattedDate, style: AppTypography.kicker),
                  ),
                  IconButton(
                    tooltip: 'Thông báo',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await communityPush(
                        context,
                        CommunityNotificationsPage(repo: repo),
                      );
                      load();
                    },
                    icon: Badge(
                      isLabelVisible:
                          (bootstrap!['notifications'] as int? ?? 0) > 0,
                      label: Text('${bootstrap!['notifications'] ?? 0}'),
                      child: const Icon(Icons.notifications_none, size: 22),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tin nhắn',
                    visualDensity: VisualDensity.compact,
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
                    tooltip: 'Thêm',
                    icon: Badge(
                      isLabelVisible: pending > 0,
                      smallSize: 8,
                      child: const Icon(Icons.more_vert, size: 22),
                    ),
                    onSelected: (v) async {
                      if (v == 'friends') {
                        await communityPush(
                          context,
                          CommunityPeoplePage(repo: repo),
                        );
                      } else if (v == 'profile') {
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
                      PopupMenuItem(
                        value: 'friends',
                        child: Row(
                          children: [
                            const Text('Bạn bè'),
                            if (pending > 0) ...[
                              const SizedBox(width: 8),
                              Badge(label: Text('$pending')),
                            ],
                          ],
                        ),
                      ),
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
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.displayMedium.copyWith(fontSize: 26),
                    children: const [
                      TextSpan(text: 'Một góc nhỏ '),
                      TextSpan(
                        text: 'để sẻ chia.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .86,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    for (final item in [
                      (0, 'Chung', Icons.public_outlined),
                      (1, 'Nhóm của tôi', Icons.lock_outline),
                    ])
                      Expanded(
                        child: Semantics(
                          selected: section == item.$1,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: section == item.$1
                                  ? AppColors.ink
                                  : Colors.transparent,
                              foregroundColor: section == item.$1
                                  ? AppColors.cream
                                  : AppColors.textSecondary,
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            onPressed: () => setState(() => section = item.$1),
                            icon: Icon(item.$3, size: 15),
                            label: Text(
                              item.$2,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              section == 0
                  ? CommunityFeed(
                      key: feedKey,
                      repo: repo,
                      emptyAction: _emptyActions(),
                      header: const CommunityWelcome(),
                    )
                  : CommunityGroups(repo: repo),
              // FAB for quick compose — always accessible while scrolling
              if (section == 0)
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: FloatingActionButton.small(
                    heroTag: 'community_compose_fab',
                    tooltip: 'Viết một chia sẻ',
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.cream,
                    onPressed: compose,
                    child: const Icon(Icons.edit_outlined, size: 20),
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

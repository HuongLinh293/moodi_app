import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import 'community_groups.dart';
import 'community_people.dart';
import 'community_posts.dart';
import 'community_repository.dart';
import 'community_widgets.dart';

class CommunityNotificationsPage extends StatefulWidget {
  const CommunityNotificationsPage({super.key, required this.repo});

  final CommunityRepository repo;

  @override
  State<CommunityNotificationsPage> createState() =>
      _CommunityNotificationsPageState();
}

class _CommunityNotificationsPageState
    extends State<CommunityNotificationsPage> {
  List<Json>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.repo.call('notifications');
      if (!mounted) return;
      setState(() {
        items = rows(data['items']);
        error = null;
      });
      if (items!.any((item) => item['isRead'] != true)) {
        await widget.repo.mutate('markNotificationsRead', const {});
      }
    } catch (e) {
      if (mounted) setState(() => error = CommunityRepository.error(e));
    }
  }

  (IconData, Color) appearance(String type) => switch (type) {
    'community_comment' => (Icons.chat_bubble_outline, AppColors.blue),
    'community_reaction' => (Icons.favorite_border, AppColors.pink),
    'community_group_invite' => (Icons.mail_outline, AppColors.mint),
    'community_friend_request' || 'community_friend_accept' => (
      Icons.person_add_alt_1_outlined,
      AppColors.orange,
    ),
    'community_message' => (Icons.mark_email_unread_outlined, AppColors.yellow),
    _ => (Icons.notifications_none, AppColors.gray),
  };

  Future<void> open(Json item) async {
    final type = item['type'] as String? ?? '';
    final data = item['data'] is Map ? json(item['data']) : <String, dynamic>{};
    Widget? page;
    if ((type == 'community_comment' || type == 'community_reaction') &&
        data['space'] != null &&
        data['postId'] != null) {
      page = CommunityPostPage(
        repo: widget.repo,
        space: data['space'],
        postId: data['postId'],
      );
    } else if (type == 'community_group_invite') {
      page = CommunityGroupPage(
        repo: widget.repo,
        space: data['space'],
        name: data['groupName'] ?? 'Nhóm riêng',
      );
    } else if (type == 'community_message') {
      page = CommunityChatPage(
        repo: widget.repo,
        target: data['target'],
        name: data['name'] ?? 'Bạn bè',
      );
    } else if (data['target'] != null) {
      page = CommunityProfilePage(repo: widget.repo, target: data['target']);
    }
    if (page != null && mounted) await communityPush(context, page);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông báo')),
    body: SafeArea(
      child: error != null
          ? CommunityEmpty(
              'Chưa tải được thông báo',
              error!,
              action: OutlinedButton(
                onPressed: load,
                child: const Text('Thử lại'),
              ),
            )
          : items == null
          ? const Center(child: CircularProgressIndicator())
          : items!.isEmpty
          ? const CommunityEmpty(
              'Hộp thư đang yên',
              'Khi có người đồng cảm, bình luận hoặc gửi lời mời, thông báo sẽ xuất hiện ở đây.',
              icon: Icons.notifications_none,
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: items!.length,
                itemBuilder: (context, index) {
                  final item = items![index];
                  final visual = appearance(item['type'] ?? '');
                  final unread = item['isRead'] != true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: unread ? const Color(0xFFFFF2C8) : AppColors.cream,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: unread ? AppColors.ink : AppColors.line,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => open(item),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: visual.$2.withValues(alpha: .2),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(visual.$1, size: 21),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['message'] ??
                                          'Bạn có thông báo mới.',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.ink,
                                        fontWeight: unread
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      communityTime(item['createdAt']),
                                      style: AppTypography.micro,
                                    ),
                                  ],
                                ),
                              ),
                              if (unread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    ),
  );
}

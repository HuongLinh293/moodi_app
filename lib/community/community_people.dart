import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import 'community_repository.dart';
import 'community_widgets.dart';
import 'community_posts.dart';

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    super.key,
    required this.repo,
    required this.target,
  });
  final CommunityRepository repo;
  final String target;
  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage> {
  Json? data;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.repo.call('profile', {
        'target': widget.target,
      });
      if (mounted) {
        setState(() {
          data = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = CommunityRepository.error(e));
    }
  }

  Future<void> action(String kind) async {
    if (['block', 'unfriend'].contains(kind) &&
        !await communityConfirm(
          context,
          kind == 'block' ? 'Chặn người này?' : 'Hủy kết bạn?',
          'Hai bạn sẽ không thể gửi tin mới. Lịch sử tin nhắn vẫn được giữ.',
        )) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repo.mutate('friendship', {
        'target': widget.target,
        'kind': kind,
      });
      await load();
    } catch (e) {
      if (mounted) communityError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = data == null ? null : json(data!['profile']);
    final r = data?['relation'] == null ? null : json(data!['relation']);
    final blocked = (r?['blockedBy'] as List? ?? []);
    final own = widget.target == widget.repo.uid;
    Widget button(String label, String kind) => OutlinedButton(
      onPressed: busy ? null : () => action(kind),
      child: Text(label),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cộng đồng')),
      body: SafeArea(
        child: error != null
            ? CommunityEmpty(
                'Chưa tải được hồ sơ',
                error!,
                action: TextButton(
                  onPressed: load,
                  child: const Text('Thử lại'),
                ),
              )
            : p == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(child: CommunityAvatar(p['name'])),
                  const SizedBox(height: 16),
                  Text(
                    p['name'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SelectableText(
                    '@${p['handle']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if ((p['bio'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(p['bio'], textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 12),
                  if (own)
                    OutlinedButton(
                      onPressed: () async {
                        await communityPush(
                          context,
                          CommunityForm(
                            title: 'Biệt danh của bạn',
                            fields: [
                              (
                                key: 'name',
                                label: 'Biệt danh',
                                max: 40,
                                initial: p['name'] as String,
                              ),
                              (
                                key: 'bio',
                                label: 'Giới thiệu ngắn',
                                max: 160,
                                initial: p['bio'] as String,
                              ),
                            ],
                            submit: (v) async {
                              await widget.repo.mutate('saveProfile', v);
                            },
                          ),
                        );
                        load();
                      },
                      child: const Text('Sửa hồ sơ'),
                    ),
                  if (!own) ...[
                    if (blocked.isEmpty && r?['status'] == 'none')
                      button('Kết bạn', 'request'),
                    if (blocked.isEmpty &&
                        r?['status'] == 'pending' &&
                        r?['requestedBy'] == widget.repo.uid)
                      button('Hủy lời mời', 'cancel'),
                    if (blocked.isEmpty &&
                        r?['status'] == 'pending' &&
                        r?['requestedBy'] != widget.repo.uid) ...[
                      button('Chấp nhận kết bạn', 'accept'),
                      button('Từ chối', 'decline'),
                    ],
                    if (r?['status'] == 'accepted' || r?['hasMessages'] == true)
                      FilledButton.icon(
                        onPressed: () => communityPush(
                          context,
                          CommunityChatPage(
                            repo: widget.repo,
                            target: widget.target,
                            name: p['name'],
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Tin nhắn'),
                      ),
                    if (r?['status'] == 'accepted')
                      button('Hủy kết bạn', 'unfriend'),
                    button(
                      blocked.contains(widget.repo.uid)
                          ? 'Bỏ chặn'
                          : 'Chặn người này',
                      blocked.contains(widget.repo.uid) ? 'unblock' : 'block',
                    ),
                    TextButton(
                      onPressed: () => reportCommunity(context, widget.repo, {
                        'target': widget.target,
                      }),
                      child: const Text('Báo cáo hồ sơ'),
                    ),
                    if (blocked.isNotEmpty)
                      const Text(
                        'Tương tác đang bị chặn.',
                        textAlign: TextAlign.center,
                      ),
                  ],
                  const Divider(height: 32),
                  const Text(
                    'Nhật ký và khu vườn riêng không hiển thị trên hồ sơ.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => communityPush(
                      context,
                      Scaffold(
                        appBar: AppBar(title: Text('Chia sẻ của ${p['name']}')),
                        body: CommunityFeed(
                          repo: widget.repo,
                          author: widget.target,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Xem bài công khai'),
                  ),
                ],
              ),
      ),
    );
  }
}

class CommunityPeoplePage extends StatefulWidget {
  const CommunityPeoplePage({
    super.key,
    required this.repo,
    this.messages = false,
  });
  final CommunityRepository repo;
  final bool messages;
  @override
  State<CommunityPeoplePage> createState() => _CommunityPeoplePageState();
}

class _CommunityPeoplePageState extends State<CommunityPeoplePage> {
  final key = GlobalKey<CommunityListState>();
  Future<void> search() async {
    Json? found;
    await communityPush(
      context,
      CommunityForm(
        title: 'Tìm bạn bằng mã',
        button: 'Tìm bạn',
        description: 'Nhập mã 12 ký tự trên hồ sơ cộng đồng của bạn bè.',
        fields: const [
          (key: 'handle', label: 'Mã bạn bè', max: 12, initial: ''),
        ],
        submit: (v) async {
          final value = await widget.repo.call('search', v);
          if (value['profile'] == null) {
            throw StateError('Không tìm thấy mã này.');
          }
          found = json(value['profile']);
        },
      ),
    );
    if (mounted && found != null) {
      await communityPush(
        context,
        CommunityProfilePage(repo: widget.repo, target: found!['id']),
      );
      key.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.messages ? 'Tin nhắn' : 'Bạn bè'),
      actions: [
        if (!widget.messages)
          IconButton(
            onPressed: search,
            tooltip: 'Tìm bạn',
            icon: const Icon(Icons.person_add_alt),
          ),
      ],
    ),
    body: SafeArea(
      child: CommunityList(
        key: key,
        load: (cursor) async {
          final value = await widget.repo.call('connections');
          return {
            'items': rows(value['items'])
                .where(
                  (r) => widget.messages
                      ? r['hasMessages'] == true || r['status'] == 'accepted'
                      : r['status'] != 'none' ||
                            (r['blockedBy'] as List).contains(widget.repo.uid),
                )
                .toList(),
          };
        },
        emptyTitle: widget.messages
            ? 'Chưa có cuộc trò chuyện'
            : 'Những kết nối bắt đầu từ một lời chào',
        emptyDescription: widget.messages
            ? 'Kết bạn trước để có thể nhắn tin riêng.'
            : 'Ghé hồ sơ tác giả hoặc tìm bạn bằng mã trên hồ sơ.',
        builder: (r, refresh) {
          final p = json(r['profile']);
          final blocked = (r['blockedBy'] as List).isNotEmpty;
          final subtitle = blocked
              ? 'Đã chặn tương tác'
              : r['status'] == 'accepted'
              ? 'Bạn bè'
              : r['status'] == 'pending'
              ? (r['requestedBy'] == widget.repo.uid
                    ? 'Đã gửi lời mời'
                    : 'Đang chờ bạn chấp nhận')
              : 'Đã hủy kết bạn';
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            leading: CommunityAvatar(p['name']),
            title: Text(p['name']),
            subtitle: Text(
              widget.messages
                  ? (r['preview'] as String? ?? '').isNotEmpty
                        ? r['preview'] as String
                        : 'Chưa có tin nhắn'
                  : subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: widget.messages
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        communityTime(r['lastMessageAt']),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (r['unread'] == true)
                        Semantics(
                          label: 'Có tin nhắn chưa đọc',
                          child: Icon(
                            Icons.circle,
                            size: 10,
                            color: AppColors.orange,
                          ),
                        ),
                    ],
                  )
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await communityPush(
                context,
                widget.messages
                    ? CommunityChatPage(
                        repo: widget.repo,
                        target: p['id'],
                        name: p['name'],
                      )
                    : CommunityProfilePage(repo: widget.repo, target: p['id']),
              );
              refresh();
            },
          );
        },
      ),
    ),
  );
}

class CommunityChatPage extends StatefulWidget {
  const CommunityChatPage({
    super.key,
    required this.repo,
    required this.target,
    required this.name,
  });
  final CommunityRepository repo;
  final String target, name;
  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage>
    with WidgetsBindingObserver {
  List<Json> items = [];
  Json? cursor, relation;
  String? error;
  bool fetching = false, first = true, foreground = true;
  Timer? timer;
  final textController = TextEditingController();
  bool sending = false;
  String? pendingText, pendingRequestId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (foreground && (ModalRoute.of(context)?.isCurrent ?? false)) load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) load();
  }

  @override
  void dispose() {
    textController.dispose();
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> sendDirectMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    if (pendingText != text || pendingRequestId == null) {
      pendingText = text;
      pendingRequestId = widget.repo.newRequestId();
    }
    final reqId = pendingRequestId!;
    try {
      await widget.repo.mutate('sendMessage', {
        'target': widget.target,
        'text': text,
      }, requestId: reqId);
      if (!mounted) return;
      if (textController.text.trim() == text) textController.clear();
      pendingText = null;
      pendingRequestId = null;
      await load();
    } catch (e) {
      if (mounted) communityError(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> load({bool older = false}) async {
    if (fetching) return;
    fetching = true;
    try {
      final data = await widget.repo.call('messages', {
        'target': widget.target,
        if (older && cursor != null) 'cursor': cursor,
      });
      if (!mounted) return;
      final fresh = rows(data['items']);
      setState(() {
        // Replace the latest window so removed messages cannot survive refresh.
        final freshIds = fresh.map((m) => m['id']).toSet();
        if (older) {
          items = [
            ...items,
            ...fresh.where((m) => !items.any((old) => old['id'] == m['id'])),
          ];
        } else if (fresh.isEmpty) {
          items = [];
        } else {
          final oldest = fresh.last['createdAt'] as num;
          items = [
            ...fresh,
            ...items.where(
              (m) =>
                  !freshIds.contains(m['id']) &&
                  (m['createdAt'] as num) < oldest,
            ),
          ];
        }
        if (first || older) {
          cursor = data['cursor'] == null ? null : json(data['cursor']);
        }
        relation = json(data['relation']);
        error = null;
        first = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          items = [];
          error = CommunityRepository.error(e);
          first = false;
        });
      }
    } finally {
      fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        relation?['status'] == 'accepted' &&
        (relation?['blockedBy'] as List? ?? []).isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ và quyền riêng tư',
            onPressed: () async {
              await communityPush(
                context,
                CommunityProfilePage(repo: widget.repo, target: widget.target),
              );
              load();
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: first
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? CommunityEmpty(
                      'Chưa tải được tin nhắn',
                      error!,
                      action: TextButton(
                        onPressed: load,
                        child: const Text('Thử lại'),
                      ),
                    )
                  : items.isEmpty
                  ? const CommunityEmpty(
                      'Một lời chào nhẹ nhàng',
                      'Chỉ hai bạn có thể đọc cuộc trò chuyện này trong app.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => load(),
                      child: ListView.builder(
                        reverse: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            return cursor == null
                                ? const SizedBox.shrink()
                                : TextButton(
                                    onPressed: () => load(older: true),
                                    child: const Text('Tin nhắn cũ hơn'),
                                  );
                          }
                          final m = items[index],
                              own = m['author'] == widget.repo.uid;
                          return Align(
                            alignment: own
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * .8,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: own
                                    ? AppColors.creamDark
                                    : AppColors.cream,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    communityTime(m['createdAt']),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                  if (m['deleted'] == true)
                                    const Text(
                                      'Tin nhắn đã được gỡ.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else ...[
                                    if ((m['text'] as String).isNotEmpty)
                                      Text(m['text']),
                                    if ((m['imagePath'] as String).isNotEmpty)
                                      CommunityPhoto(
                                        key: ValueKey(m['id']),
                                        repo: widget.repo,
                                        scope: {
                                          'target': widget.target,
                                          'messageId': m['id'],
                                        },
                                      ),
                                    if (!own)
                                      TextButton(
                                        onPressed: () => reportCommunity(
                                          context,
                                          widget.repo,
                                          {
                                            'target': widget.target,
                                            'messageId': m['id'],
                                          },
                                        ),
                                        child: const Text(
                                          'Báo cáo',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: canSend
                  ? Row(
                      children: [
                        IconButton(
                          tooltip: 'Gửi ảnh hoặc soạn tin chi tiết',
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.ink,
                          ),
                          onPressed: () async {
                            await communityPush(
                              context,
                              CommunityComposer(
                                repo: widget.repo,
                                destination: widget.name,
                                scope: {'target': widget.target},
                                message: true,
                              ),
                            );
                            load();
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: textController,
                            enabled: !sending,
                            maxLength: 4000,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => sendDirectMessage(),
                            decoration: InputDecoration(
                              hintText: 'Nhắn điều bạn muốn chia sẻ…',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.creamDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Gửi',
                          icon: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: AppColors.ink,
                                ),
                          onPressed: sending ? null : sendDirectMessage,
                        ),
                      ],
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'Kết bạn và bỏ chặn để gửi tin mới.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

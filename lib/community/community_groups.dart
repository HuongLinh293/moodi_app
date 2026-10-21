import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

import 'community_repository.dart';
import 'community_widgets.dart';
import 'community_posts.dart';
import 'community_people.dart';

class CommunityGroups extends StatefulWidget {
  const CommunityGroups({super.key, required this.repo});
  final CommunityRepository repo;
  @override
  State<CommunityGroups> createState() => _CommunityGroupsState();
}

class _CommunityGroupsState extends State<CommunityGroups> {
  final key = GlobalKey<CommunityListState>();
  Future<void> create() async {
    final requestId = widget.repo.newRequestId();
    String? groupId;
    await communityPush(
      context,
      CommunityForm(
        title: 'Tạo nhóm riêng',
        button: 'Tạo nhóm',
        description: 'Chỉ người nhận lời mời và chấp nhận mới trở thành thành viên. Nhật ký riêng không được đưa vào nhóm.',
        fields: const [
          (key: 'name', label: 'Tên nhóm', max: 60, initial: ''),
          (
            key: 'description',
            label: 'Vài dòng về nhóm',
            max: 240,
            initial: '',
          ),
        ],
        submit: (v) async {
          groupId = (await widget.repo.mutate(
            'createGroup',
            v,
            requestId: requestId,
          ))['id'];
        },
      ),
    );
    if (mounted && groupId != null) {
      await communityPush(
        context,
        CommunityGroupPage(
          repo: widget.repo,
          space: groupId!,
          name: 'Nhóm của bạn',
        ),
      );
    }
    key.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => CommunityList(
    key: key,
    load: (cursor) async {
      final d = await widget.repo.call('groups');
      return {
        'items': [
          ...rows(d['invites']).map((g) => {...g, 'invitation': true}),
          ...rows(d['items']),
        ],
      };
    },
    header: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: create,
        icon: const Icon(Icons.add),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Tạo nhóm riêng'),
        ),
      ),
    ),
    emptyTitle: 'Một góc nhỏ cho những người bạn tin',
    emptyDescription: 'Tạo nhóm để chia sẻ câu chuyện với bạn bè hoặc gia đình. Nhóm chỉ mở cho người được mời.',
    builder: (g, refresh) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: Text(g['name']),
              subtitle: Text(g['description'] ?? ''),
              onTap: g['invitation'] == true
                  ? null
                  : () async {
                      await communityPush(
                        context,
                        CommunityGroupPage(
                          repo: widget.repo,
                          space: g['id'],
                          name: g['name'],
                        ),
                      );
                      refresh();
                    },
            ),
            if (g['invitation'] == true) ...[
              const Text('Bạn được mời tham gia nhóm'),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in [
                    ('accept', 'Tham gia'),
                    ('decline', 'Từ chối'),
                  ])
                    TextButton(
                      onPressed: () async {
                        try {
                          await widget.repo.mutate('groupAction', {
                            'space': g['id'],
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
          ],
        ),
      ),
    ),
  );
}

class CommunityGroupPage extends StatefulWidget {
  const CommunityGroupPage({
    super.key,
    required this.repo,
    required this.space,
    required this.name,
  });
  final CommunityRepository repo;
  final String space, name;
  @override
  State<CommunityGroupPage> createState() => _CommunityGroupPageState();
}

class _CommunityGroupPageState extends State<CommunityGroupPage> {
  int revision = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.name),
      actions: [
        IconButton(
          tooltip: 'Thành viên và quản lý nhóm',
          icon: const Icon(Icons.group_outlined),
          onPressed: () async {
            await communityPush(
              context,
              CommunityGroupSettings(repo: widget.repo, space: widget.space),
            );
            if (mounted) setState(() => revision++);
          },
        ),
      ],
    ),
    body: SafeArea(
      child: CommunityFeed(
        key: ValueKey(revision),
        repo: widget.repo,
        space: widget.space,
        name: widget.name,
      ),
    ),
  );
}

class CommunityGroupSettings extends StatefulWidget {
  const CommunityGroupSettings({
    super.key,
    required this.repo,
    required this.space,
  });
  final CommunityRepository repo;
  final String space;
  @override
  State<CommunityGroupSettings> createState() => _CommunityGroupSettingsState();
}

class _CommunityGroupSettingsState extends State<CommunityGroupSettings> {
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
      final d = await widget.repo.call('group', {'space': widget.space});
      if (mounted) {
        setState(() {
          data = d;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          data = null;
          error = CommunityRepository.error(e);
        });
      }
    }
  }

  Future<void> act(String kind, {String? target}) async {
    final group = json(data!['group']);
    final name = group['name'] as String;
    final people = [...rows(data!['members']), ...rows(data!['invited'])];
    final person =
        people.where((p) => p['id'] == target).firstOrNull?['name'] ??
        'thành viên này';
    final invited = rows(data!['invited']).any((p) => p['id'] == target);
    final (title, body) = switch (kind) {
      'close' => (
        'Đóng nhóm "$name"?',
        'Tất cả thành viên sẽ mất quyền truy cập bài và ảnh trong nhóm. Nhóm không thể mở lại trong app.',
      ),
      'leave' => (
        'Rời nhóm "$name"?',
        'Bạn sẽ không xem được bài và ảnh trong nhóm. Muốn tham gia lại, bạn cần lời mời mới.',
      ),
      'transfer' => (
        'Chuyển quyền cho $person?',
        '$person sẽ trở thành chủ nhóm "$name". Bạn vẫn là thành viên nhưng mất quyền quản lý nhóm.',
      ),
      'remove' =>
        invited
            ? (
                'Thu hồi lời mời của $person?',
                '$person sẽ không thể dùng lời mời này để vào nhóm "$name".',
              )
            : (
                'Mời $person rời nhóm?',
                '$person sẽ mất quyền xem bài và ảnh trong nhóm "$name".',
              ),
      _ => ('Xác nhận thao tác?', 'Thao tác này thay đổi nhóm "$name".'),
    };
    if (!await communityConfirm(context, title, body)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.repo.mutate('groupAction', {
        'space': widget.space,
        'kind': kind,
        'target': ?target,
      });
      await load();
    } catch (e) {
      if (mounted) communityError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> invite() async {
    final existingMemberIds = <String>{
      if (data != null)
        for (final m in rows(data!['members'])) m['id'] as String,
      if (data != null)
        for (final m in rows(data!['invited'])) m['id'] as String,
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommunityGroupInviteSheet(
        repo: widget.repo,
        space: widget.space,
        existingMemberIds: existingMemberIds,
      ),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    final g = data == null ? null : json(data!['group']);
    final owner = g?['owner'] == widget.repo.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Thành viên nhóm')),
      body: SafeArea(
        child: error != null
            ? CommunityEmpty('Không truy cập được nhóm', error!)
            : g == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    g['name'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(g['description']),
                  const SizedBox(height: 16),
                  const Text(
                    'Chỉ thành viên mới xem được bài trong nhóm. Người nhận vẫn có thể chụp hoặc lưu lại nội dung.',
                  ),
                  const SizedBox(height: 16),
                  if (owner)
                    OutlinedButton.icon(
                      onPressed: busy ? null : invite,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Mời thành viên'),
                    ),
                  for (final p in rows(data!['members']))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CommunityAvatar(p['name']),
                      title: Text(p['name']),
                      subtitle: Text(
                        p['id'] == g['owner'] ? 'Chủ nhóm' : 'Thành viên',
                      ),
                      onTap: () => communityPush(
                        context,
                        CommunityProfilePage(
                          repo: widget.repo,
                          target: p['id'],
                        ),
                      ),
                      trailing: owner && p['id'] != widget.repo.uid
                          ? PopupMenuButton<String>(
                              enabled: !busy,
                              tooltip: 'Quản lý thành viên',
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Mời rời nhóm'),
                                ),
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Text('Chuyển quyền chủ nhóm'),
                                ),
                              ],
                              onSelected: (kind) => act(kind, target: p['id']),
                            )
                          : null,
                    ),
                  if (owner && rows(data!['invited']).isNotEmpty) ...[
                    const Divider(),
                    const Text('Lời mời đang chờ'),
                    for (final p in rows(data!['invited']))
                      ListTile(
                        title: Text(p['name']),
                        trailing: TextButton(
                          onPressed: busy
                              ? null
                              : () => act('remove', target: p['id']),
                          child: const Text('Thu hồi'),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => act(owner ? 'close' : 'leave'),
                    child: Text(owner ? 'Đóng nhóm' : 'Rời nhóm'),
                  ),
                  if (owner)
                    const Text(
                      'Để rời nhóm mà vẫn giữ nhóm, hãy chuyển quyền cho một thành viên khác.',
                    ),
                ],
              ),
      ),
    );
  }
}

class CommunityGroupInviteSheet extends StatefulWidget {
  const CommunityGroupInviteSheet({
    super.key,
    required this.repo,
    required this.space,
    required this.existingMemberIds,
  });

  final CommunityRepository repo;
  final String space;
  final Set<String> existingMemberIds;

  @override
  State<CommunityGroupInviteSheet> createState() =>
      _CommunityGroupInviteSheetState();
}

class _CommunityGroupInviteSheetState extends State<CommunityGroupInviteSheet> {
  bool loading = true;
  String? error;
  List<Json> friends = [];
  final Set<String> invitedTargets = {};
  final handleController = TextEditingController();
  bool searchBusy = false;

  @override
  void initState() {
    super.initState();
    loadFriends();
  }

  @override
  void dispose() {
    handleController.dispose();
    super.dispose();
  }

  Future<void> loadFriends() async {
    try {
      final value = await widget.repo.call('connections');
      final all = rows(value['items']);
      final friendItems = all.where((r) {
        if (r['status'] != 'accepted') return false;
        final p = json(r['profile']);
        return !widget.existingMemberIds.contains(p['id']);
      }).toList();
      if (mounted) {
        setState(() {
          friends = friendItems;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = CommunityRepository.error(e);
          loading = false;
        });
      }
    }
  }

  Future<void> sendInvite(String targetId) async {
    setState(() => invitedTargets.add(targetId));
    try {
      await widget.repo.mutate('invite', {
        'space': widget.space,
        'target': targetId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lời mời vào nhóm.')),
        );
      }
    } catch (e) {
      setState(() => invitedTargets.remove(targetId));
      if (mounted) communityError(context, e);
    }
  }

  Future<void> inviteByHandle() async {
    final handle = handleController.text.trim();
    if (handle.isEmpty) return;
    setState(() => searchBusy = true);
    try {
      final d = await widget.repo.call('search', {'handle': handle});
      if (d['profile'] == null) {
        throw StateError('Không tìm thấy người này.');
      }
      final targetId = json(d['profile'])['id'] as String;
      await widget.repo.mutate('invite', {
        'space': widget.space,
        'target': targetId,
      });
      handleController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lời mời vào nhóm.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) communityError(context, e);
    } finally {
      if (mounted) setState(() => searchBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mời vào nhóm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: handleController,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mã bạn bè (12 ký tự)',
                        counterText: '',
                        isDense: true,
                        prefixIcon: Icon(Icons.tag, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: searchBusy ? null : inviteByHandle,
                    child: Text(searchBusy ? 'Đang tìm…' : 'Mời'),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Bạn bè của bạn (chạm để mời)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(child: Text(error!))
                    : friends.isEmpty
                    ? const Center(
                        child: Text(
                          'Tất cả bạn bè đã tham gia nhóm hoặc bạn chưa có bạn bè mới.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final f = friends[i];
                          final p = json(f['profile']);
                          final isInvited = invitedTargets.contains(p['id']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CommunityAvatar(p['name']),
                            title: Text(p['name']),
                            subtitle: Text('@${p['handle'] ?? ''}'),
                            trailing: isInvited
                                ? const Chip(
                                    label: Text(
                                      'Đã mời',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: AppColors.creamDark,
                                  )
                                : FilledButton.tonal(
                                    onPressed: () => sendInvite(p['id']),
                                    child: const Text('Mời'),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

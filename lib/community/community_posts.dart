import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/colors.dart';
import 'community_repository.dart';
import 'community_widgets.dart';
import 'community_people.dart';

const communityMoods = [
  'Vui vẻ',
  'Bình yên',
  'Buồn',
  'Lo lắng',
  'Áp lực',
  'Tức giận',
  'Biết ơn',
  'Mệt mỏi',
];
const communityIntents = [
  'Chỉ muốn được lắng nghe',
  'Muốn nghe lời khuyên',
  'Có ai từng trải qua không?',
  'Chia sẻ chuyện vui',
];

Future<void> reportCommunity(
  BuildContext context,
  CommunityRepository repo,
  Json scope,
) async {
  final requestId = repo.newRequestId();
  await communityPush(
    context,
    CommunityForm(
      title: 'Báo cáo nội dung',
      button: 'Gửi báo cáo',
      description: 'Nội dung được báo cáo sẽ được gửi cho người quản trị xem xét. Danh tính của bạn không hiển thị công khai.',
      fields: const [
        (key: 'reason', label: 'Lý do báo cáo', max: 500, initial: ''),
      ],
      submit: (values) async {
        await repo.mutate('report', {
          ...scope,
          ...values,
        }, requestId: requestId);
      },
    ),
  );
}

/// Shared composer for posts and messages. Stable request ID survives a failed
/// attempt; changing the draft creates a new ID, preventing duplicate retries.
class CommunityComposer extends StatefulWidget {
  const CommunityComposer({
    super.key,
    required this.repo,
    required this.destination,
    required this.scope,
    this.message = false,
  });
  final CommunityRepository repo;
  final String destination;
  final Json scope;
  final bool message;
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  final text = TextEditingController();
  Uint8List? photo;
  String mood = '', intent = '', lastPayload = '', requestId = '';
  String? error;
  bool busy = false, sent = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 1000000) {
        throw StateError('Ảnh quá lớn. Hãy chọn ảnh dưới 1 MB.');
      }
      if (mounted) {
        setState(() {
          photo = bytes;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = CommunityRepository.error(e));
    }
  }

  Future<void> send() async {
    if (text.text.trim().isEmpty && photo == null) {
      setState(() => error = 'Hãy viết vài dòng hoặc thêm một ảnh.');
      return;
    }
    final payload = {
      ...widget.scope,
      'text': text.text.trim(),
      if (photo != null) 'image': base64Encode(photo!),
      if (!widget.message) ...{'mood': mood, 'intent': intent},
    };
    final encoded = jsonEncode(payload);
    if (encoded != lastPayload) {
      lastPayload = encoded;
      requestId = widget.repo.newRequestId();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.mutate(
        widget.message ? 'sendMessage' : 'createPost',
        payload,
        requestId: requestId,
      );
      if (mounted) {
        setState(() {
          sent = true;
          busy = false;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = CommunityRepository.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: sent || (!busy && text.text.isEmpty && photo == null),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || busy) return;
      if (await communityConfirm(
            context,
            'Bỏ bản nháp?',
            'Nội dung chưa gửi sẽ không được lưu.',
          ) &&
          mounted) {
        setState(() => sent = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.message ? 'Viết tin nhắn' : 'Viết chia sẻ'),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.scope['space'] == 'public'
                        ? Icons.public
                        : Icons.lock_outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message
                              ? 'Gửi đến: ${widget.destination}'
                              : 'Đăng tại: ${widget.destination}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.message
                              ? 'Chỉ hai bạn có thể đọc trong app.'
                              : widget.scope['space'] == 'public'
                              ? 'Mọi người trong app có thể xem.'
                              : 'Chỉ thành viên nhóm có thể xem.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: text,
              enabled: !busy,
              maxLength: 4000,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: widget.message
                    ? 'Lời nhắn của bạn'
                    : 'Bạn muốn chia sẻ điều gì?',
                alignLabelWithHint: true,
              ),
            ),
            if (!widget.message) ...[
              const SizedBox(height: 4),
              const Text(
                'Cảm xúc (tùy chọn)',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in communityMoods)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(m),
                          selected: mood == m,
                          onSelected: busy
                              ? null
                              : (on) => setState(() => mood = on ? m : ''),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn muốn được phản hồi thế nào?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final i in communityIntents)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(i),
                          selected: intent == i,
                          onSelected: busy
                              ? null
                              : (on) => setState(() => intent = on ? i : ''),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(photo!, height: 220, fit: BoxFit.cover),
              ),
              TextButton(
                onPressed: busy ? null : () => setState(() => photo = null),
                child: const Text('Bỏ ảnh'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: busy ? null : pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(photo == null ? 'Thêm ảnh' : 'Chọn ảnh khác'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : send,
              child: Text(
                busy
                    ? 'Đang gửi…'
                    : widget.message
                    ? 'Gửi tin nhắn'
                    : widget.scope['space'] == 'public'
                    ? 'Đăng công khai'
                    : 'Đăng vào nhóm',
              ),
            ),
          ],
          ),
        ),
      ),
    ),
  );
}

class CommunityFeed extends StatefulWidget {
  const CommunityFeed({
    super.key,
    required this.repo,
    this.space = 'public',
    this.name = 'Cộng đồng chung',
    this.author,
    this.emptyAction,
  });
  final CommunityRepository repo;
  final String space, name;
  final String? author;
  final Widget? emptyAction;
  @override
  State<CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends State<CommunityFeed> {
  final listKey = GlobalKey<CommunityListState>();
  String? selectedMood;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.space == 'public')
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selectedMood == null,
                    label: const Text('Tất cả'),
                    selectedColor: AppColors.ink,
                    labelStyle: TextStyle(
                      color: selectedMood == null
                          ? AppColors.cream
                          : AppColors.ink,
                      fontWeight: selectedMood == null
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      if (selectedMood != null) {
                        setState(() => selectedMood = null);
                        listKey.currentState?.refresh(clear: true);
                      }
                    },
                  ),
                ),
                for (final mood in communityMoods)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selectedMood == mood,
                      label: Text(mood),
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: selectedMood == mood
                            ? AppColors.cream
                            : AppColors.ink,
                        fontWeight: selectedMood == mood
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedMood = selectedMood == mood ? null : mood;
                        });
                        listKey.currentState?.refresh(clear: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: CommunityList(
            key: listKey,
            load: (cursor) => widget.repo.call('feed', {
              'space': widget.space,
              'cursor': ?cursor,
              if (widget.author != null) 'author': widget.author,
              if (selectedMood != null) 'mood': selectedMood,
            }),
            emptyTitle: selectedMood == null
                ? 'Hôm nay điều gì đang ở trong lòng bạn?'
                : 'Chưa có chia sẻ nào về "$selectedMood"',
            emptyDescription: selectedMood == null
                ? 'Viết một chia sẻ, tìm người đồng cảm, hoặc tạo nhóm riêng cho người bạn tin.'
                : 'Hãy là người đầu tiên chia sẻ cảm xúc này.',
            emptyAction: selectedMood == null ? widget.emptyAction : null,
            header: null,
            builder: (post, refresh) => CommunityPostCard(
              key: ValueKey(post['id']),
              repo: widget.repo,
              space: widget.space,
              post: post,
              refresh: refresh,
              onChanged: (updated) =>
                  listKey.currentState?.replaceItem(updated),
            ),
          ),
        ),
      ],
    );
  }
}

class CommunityPostCard extends StatefulWidget {
  const CommunityPostCard({
    super.key,
    required this.repo,
    required this.space,
    required this.post,
    required this.refresh,
    this.detail = false,
    this.onChanged,
  });
  final CommunityRepository repo;
  final String space;
  final Json post;
  final VoidCallback refresh;
  final bool detail;
  final ValueChanged<Json>? onChanged;
  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  bool busy = false;
  Json get scope => {'space': widget.space, 'postId': widget.post['id']};
  Future<void> act(String action, Json data) async {
    setState(() => busy = true);
    try {
      final result = await widget.repo.mutate(action, {...scope, ...data});
      if (!mounted) return;
      if (action == 'react' && widget.onChanged != null) {
        widget.onChanged!({
          ...widget.post,
          'liked': result['liked'] ?? data['enabled'],
          'likes':
              result['likes'] ??
              (widget.post['likes'] as int) +
                  (data['enabled'] == true ? 1 : -1),
        });
      } else {
        widget.refresh();
      }
    } catch (e) {
      if (mounted) communityError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post, own = p['author'] == widget.repo.uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lineLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityAvatar(p['authorName'] as String? ?? 'Bạn'),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () async {
                    await communityPush(
                      context,
                      CommunityProfilePage(
                        repo: widget.repo,
                        target: p['author'],
                      ),
                    );
                    widget.refresh();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['authorName'] ?? 'Bạn',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        communityTime(p['createdAt']),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn bài viết',
                onSelected: (value) async {
                  if (value == 'report') {
                    await reportCommunity(context, widget.repo, scope);
                  } else if (value == 'block') {
                    if (await communityConfirm(
                      context,
                      'Chặn người này?',
                      'Bạn sẽ không còn thấy bài của họ, và hai bên không tương tác được.',
                    )) {
                      await widget.repo.mutate('friendship', {
                        'target': p['author'],
                        'kind': 'block',
                      });
                      widget.refresh();
                    }
                  } else if (value == 'delete') {
                    if (await communityConfirm(
                      context,
                      'Xóa bài viết?',
                      'Bài viết sẽ được gỡ khỏi nơi đã chia sẻ.',
                    )) {
                      await act('deletePost', {});
                    }
                  } else if (value == 'comments') {
                    await act('toggleComments', {
                      'enabled': p['commentsOpen'] != true,
                    });
                  }
                },
                itemBuilder: (_) => [
                  if (own || p['canDelete'] == true)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa bài viết'),
                    ),
                  if (own)
                    PopupMenuItem(
                      value: 'comments',
                      child: Text(
                        p['commentsOpen'] == true
                            ? 'Tắt bình luận'
                            : 'Mở bình luận',
                      ),
                    ),
                  if (!own) ...[
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Báo cáo'),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Text('Chặn người này'),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if ((p['mood'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                p['mood'],
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if ((p['text'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                p['text'],
                style: const TextStyle(fontSize: 16, height: 1.55),
              ),
            ),
          if ((p['imagePath'] as String? ?? '').isNotEmpty)
            CommunityPhoto(repo: widget.repo, scope: scope),
          if ((p['intent'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                p['intent'],
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => act('react', {'enabled': p['liked'] != true}),
                icon: Icon(
                  p['liked'] == true ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                ),
                label: Text('Đồng cảm · ${p['likes'] ?? 0}'),
              ),
              if (!own)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => reportCommunity(context, widget.repo, scope),
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  label: const Text('Báo cáo'),
                ),
              if (!widget.detail)
                TextButton.icon(
                  onPressed: () async {
                    await communityPush(
                      context,
                      CommunityPostPage(
                        repo: widget.repo,
                        space: widget.space,
                        postId: p['id'],
                      ),
                    );
                    widget.refresh();
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Bình luận'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommunityPostPage extends StatefulWidget {
  const CommunityPostPage({
    super.key,
    required this.repo,
    required this.space,
    required this.postId,
  });
  final CommunityRepository repo;
  final String space, postId;
  @override
  State<CommunityPostPage> createState() => _CommunityPostPageState();
}

class _CommunityPostPageState extends State<CommunityPostPage> {
  Json? post;
  String? error;
  int revision = 0;
  Json get scope => {'space': widget.space, 'postId': widget.postId};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.repo.call('post', scope);
      if (mounted) {
        setState(() {
          post = json(data['post']);
          error = null;
          revision++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          post = null;
          error = CommunityRepository.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Câu chuyện')),
    body: SafeArea(
      child: error != null
          ? CommunityEmpty(
              'Bài viết chưa sẵn sàng',
              error!,
              action: TextButton(onPressed: load, child: const Text('Thử lại')),
            )
          : post == null
          ? const Center(child: CircularProgressIndicator())
          : CommunityList(
              key: ValueKey(revision),
              load: (cursor) =>
                  widget.repo.call('comments', {...scope, 'cursor': ?cursor}),
              emptyTitle: 'Chưa có bình luận',
              emptyDescription:
                  'Một lời lắng nghe cũng có thể mang lại sự đồng cảm.',
              header: Column(
                children: [
                  CommunityPostCard(
                    repo: widget.repo,
                    space: widget.space,
                    post: post!,
                    refresh: load,
                    detail: true,
                  ),
                  if (post!['commentsOpen'] == true)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final requestId = widget.repo.newRequestId();
                        await communityPush(
                          context,
                          CommunityForm(
                            title: 'Viết bình luận',
                            button: 'Gửi bình luận',
                            fields: const [
                              (
                                key: 'text',
                                label: 'Lời của bạn',
                                max: 2000,
                                initial: '',
                              ),
                            ],
                            submit: (v) async {
                              await widget.repo.mutate('comment', {
                                ...scope,
                                ...v,
                              }, requestId: requestId);
                            },
                          ),
                        );
                        load();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Viết bình luận'),
                    )
                  else
                    const Text('Tác giả đã tắt bình luận.'),
                  const SizedBox(height: 16),
                ],
              ),
              builder: (c, refresh) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CommunityAvatar(c['authorName'] ?? 'Bạn'),
                title: Text(c['authorName'] ?? 'Bạn'),
                subtitle: Text(c['text'] ?? ''),
                onTap: () => communityPush(
                  context,
                  CommunityProfilePage(repo: widget.repo, target: c['author']),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Tùy chọn bình luận',
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: c['canDelete'] == true ? 'delete' : 'report',
                      child: Text(c['canDelete'] == true ? 'Xóa' : 'Báo cáo'),
                    ),
                  ],
                  onSelected: (value) async {
                    try {
                      if (value == 'delete') {
                        await widget.repo.mutate('deleteComment', {
                          ...scope,
                          'commentId': c['id'],
                        });
                        refresh();
                      } else if (context.mounted) {
                        await reportCommunity(context, widget.repo, {
                          ...scope,
                          'commentId': c['id'],
                        });
                      }
                    } catch (e) {
                      if (context.mounted) communityError(context, e);
                    }
                  },
                ),
              ),
            ),
    ),
  );
}

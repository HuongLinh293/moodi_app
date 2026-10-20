import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/post_repository.dart';
import '../state/mindra_state.dart';

class PostsFeedView extends StatefulWidget {
  const PostsFeedView({super.key});

  @override
  State<PostsFeedView> createState() => _PostsFeedViewState();
}

class _PostsFeedViewState extends State<PostsFeedView> {
  final _contentCtrl = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    // Load posts when view initializes
    Future.microtask(
      () => context.read<MindraState>()._loadPosts(),
    );
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (_contentCtrl.text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      await context
          .read<MindraState>()
          .createPost(_contentCtrl.text, null);
      _contentCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài viết đã được tạo')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindraState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Tin'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Create Post Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // User Avatar + Input
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _contentCtrl,
                            decoration: InputDecoration(
                              hintText: 'Bạn cảm thấy gì hôm nay?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            maxLines: null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tính năng upload sẽ được thêm'),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.emoji_emotions),
                              onPressed: null,
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _isPosting ? null : _createPost,
                          child: _isPosting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Đăng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Posts List
          Expanded(
            child: state.posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có bài viết nào',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.posts.length,
                    itemBuilder: (context, index) {
                      final post = state.posts[index];
                      return PostCard(post: post, state: state);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final MindraState state;

  const PostCard({
    required this.post,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: post.author.avatar != null
                      ? NetworkImage(post.author.avatar!)
                      : null,
                  child: post.author.avatar == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '@${post.author.username}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              post.content,
              style: const TextStyle(fontSize: 14),
            ),

            // Images
            if (post.imageUrls != null && post.imageUrls!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: post.imageUrls!
                      .take(3)
                      .map(
                        (url) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image),
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            const SizedBox(height: 12),

            // Timestamp
            Text(
              _formatTime(post.createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 12),

            // Likes & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${post.likesCount} lượt thích',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          context.read<MindraState>().likePost(post.id),
                      icon: Icon(
                        post.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.isLiked ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.comment, size: 20),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m trước';
    if (diff.inHours < 24) return '${diff.inHours}h trước';
    if (diff.inDays < 7) return '${diff.inDays}d trước';

    return '${date.day}/${date.month}/${date.year}';
  }
}

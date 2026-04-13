import 'package:flutter/material.dart';
import '../services/places_api.dart';
import '../widgets/create_post_sheet.dart';

class PostsScreen extends StatefulWidget {
  final Place place;
  final PlacesApi api;

  const PostsScreen({super.key, required this.place, required this.api});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await widget.api.fetchPosts(widget.place.id);
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreatePost() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => CreatePostSheet(place: widget.place, api: widget.api),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final placeName =
        widget.place.name.isEmpty ? 'Unknown' : widget.place.name;

    return Scaffold(
      appBar: AppBar(
        title: Text('Posts — $placeName'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Create Post'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No posts yet.\nBe the first to share your visit!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) =>
                            _PostCard(post: _posts[i], api: widget.api),
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────
// Single post card — stateful for comment thread
// ─────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final Post post;
  final PlacesApi api;

  const _PostCard({required this.post, required this.api});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _commentsExpanded = false;
  List<Comment> _comments = [];
  bool _loadingComments = false;
  bool _submitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await widget.api.fetchComments(widget.post.id);
      if (mounted) setState(() => _comments = comments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load comments: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _toggleComments() {
    setState(() => _commentsExpanded = !_commentsExpanded);
    if (_commentsExpanded && _comments.isEmpty) _loadComments();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final comment = await widget.api.createComment(widget.post.id, text);
      if (mounted) {
        _commentController.clear();
        setState(() => _comments = [..._comments, comment]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _report() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post reported!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final post = widget.post;
    final imageUrl =
        post.imageUrl != null ? '${widget.api.baseUrl}${post.imageUrl}' : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    post.username.isNotEmpty
                        ? post.username[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.username,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        _timeAgo(post.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _report,
                  icon: Icon(Icons.flag_outlined,
                      size: 20, color: cs.onSurfaceVariant),
                  tooltip: 'Report post',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Post content ────────────────────────────
            Text(post.content,
                style: Theme.of(context).textTheme.bodyMedium),

            // ── Image ───────────────────────────────────
            if (imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: cs.surfaceContainerHighest,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ],

            // ── Comment toggle button ───────────────────
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _toggleComments,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _commentsExpanded
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _commentsExpanded
                          ? 'Hide comments'
                          : 'Comments${_comments.isNotEmpty ? ' (${_comments.length})' : ''}',
                      style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // ── Comments section ────────────────────────
            if (_commentsExpanded) ...[
              const SizedBox(height: 8),
              if (_loadingComments)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No comments yet. Be the first!',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CommentTile(
                    comment: _comments[i],
                    timeAgo: _timeAgo,
                  ),
                ),

              // ── New comment input ──────────────────────
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      decoration: InputDecoration(
                        hintText: 'Write a comment…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          onPressed: _submitComment,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          tooltip: 'Send',
                        ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Single comment row
// ─────────────────────────────────────────────
class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String Function(DateTime) timeAgo;

  const _CommentTile({required this.comment, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.secondaryContainer,
            child: Text(
              comment.username.isNotEmpty
                  ? comment.username[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(timeAgo(comment.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

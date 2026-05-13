import 'package:flutter/material.dart';
import '../services/places_api.dart';

class AdminScreen extends StatefulWidget {
  final PlacesApi api;
  const AdminScreen({super.key, required this.api});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<PostReport> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reports = await widget.api.fetchReports();
      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePost(PostReport report) async {
    final confirmed = await _confirm(
      'Delete Post',
      'This will permanently delete the post by "${report.author}" and all its comments.',
    );
    if (!confirmed) return;
    try {
      await widget.api.adminDeletePost(report.postId);
      if (mounted) {
        setState(() => _reports.removeWhere((r) => r.postId == report.postId));
        _snack('Post deleted.');
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _dismiss(PostReport report) async {
    final confirmed = await _confirm(
      'Dismiss Reports',
      'This clears all reports for this post without deleting it.',
    );
    if (!confirmed) return;
    try {
      await widget.api.dismissReports(report.postId);
      if (mounted) {
        setState(() => _reports.removeWhere((r) => r.postId == report.postId));
        _snack('Reports dismissed.');
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ==
        true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cs.error),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error)),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 64, color: cs.outlineVariant),
                          const SizedBox(height: 12),
                          Text('No reported posts.',
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _ReportCard(
                          report: _reports[i],
                          api: widget.api,
                          timeAgo: _timeAgo,
                          onDeletePost: () => _deletePost(_reports[i]),
                          onDismiss: () => _dismiss(_reports[i]),
                        ),
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────
// Single report card
// ─────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final PostReport report;
  final PlacesApi api;
  final String Function(DateTime) timeAgo;
  final VoidCallback onDeletePost;
  final VoidCallback onDismiss;

  const _ReportCard({
    required this.report,
    required this.api,
    required this.timeAgo,
    required this.onDeletePost,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl =
        report.imageUrl != null ? '${api.baseUrl}${report.imageUrl}' : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report badge
            Row(
              children: [
                Icon(Icons.flag_rounded, color: cs.error, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${report.reportCount} report${report.reportCount > 1 ? 's' : ''}',
                  style: TextStyle(
                      color: cs.error, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('· first ${timeAgo(report.firstReportedAt)}',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const Divider(height: 16),
            // Author
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    report.author.isNotEmpty
                        ? report.author[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(report.author,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            // Content
            Text(report.content,
                style: Theme.of(context).textTheme.bodyMedium),
            // Image
            if (imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: cs.surfaceContainerHighest,
                    child: Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: cs.onSurfaceVariant)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError),
                    onPressed: onDeletePost,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete Post'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

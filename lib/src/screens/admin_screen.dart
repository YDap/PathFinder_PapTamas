import 'package:flutter/material.dart';
import '../services/places_api.dart';

class AdminScreen extends StatefulWidget {
  final PlacesApi api;
  const AdminScreen({super.key, required this.api});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<PostReport> _postReports = [];
  List<PlaceReport> _placeReports = [];
  bool _loadingPosts = true;
  bool _loadingPlaces = true;
  String? _postError;
  String? _placeError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
    _loadPlaces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() { _loadingPosts = true; _postError = null; });
    try {
      final reports = await widget.api.fetchReports();
      if (mounted) { setState(() => _postReports = reports); }
    } catch (e) {
      if (mounted) { setState(() => _postError = e.toString()); }
    } finally {
      if (mounted) { setState(() => _loadingPosts = false); }
    }
  }

  Future<void> _loadPlaces() async {
    setState(() { _loadingPlaces = true; _placeError = null; });
    try {
      final reports = await widget.api.fetchPlaceReports();
      if (mounted) { setState(() => _placeReports = reports); }
    } catch (e) {
      if (mounted) { setState(() => _placeError = e.toString()); }
    } finally {
      if (mounted) { setState(() => _loadingPlaces = false); }
    }
  }

  Future<void> _deletePost(PostReport report) async {
    if (!await _confirm('Delete Post',
        'This will permanently delete the post by "${report.author}" and all its comments.')) return;
    try {
      await widget.api.adminDeletePost(report.postId);
      if (mounted) {
        setState(() => _postReports.removeWhere((r) => r.postId == report.postId));
        _snack('Post deleted.');
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _dismissPost(PostReport report) async {
    if (!await _confirm('Dismiss Reports',
        'This clears all reports for this post without deleting it.')) return;
    try {
      await widget.api.dismissReports(report.postId);
      if (mounted) {
        setState(() => _postReports.removeWhere((r) => r.postId == report.postId));
        _snack('Reports dismissed.');
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _deletePlace(PlaceReport report) async {
    if (!await _confirm('Delete Place',
        'This will permanently delete "${report.name.isEmpty ? 'this place' : report.name}" and all its posts and ratings.')) return;
    try {
      await widget.api.adminDeletePlace(report.placeId);
      if (mounted) {
        setState(() => _placeReports.removeWhere((r) => r.placeId == report.placeId));
        _snack('Place deleted.');
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _dismissPlaceReports(PlaceReport report) async {
    if (!await _confirm('Dismiss Reports',
        'This clears all reports for this place without deleting it.')) return;
    try {
      await widget.api.adminDismissPlaceReports(report.placeId);
      if (mounted) {
        setState(() => _placeReports.removeWhere((r) => r.placeId == report.placeId));
        _snack('Reports dismissed.');
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      ) == true;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
            onPressed: () { _loadPosts(); _loadPlaces(); },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.article_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('Posts'),
                if (_postReports.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Badge(count: _postReports.length),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('Places'),
                if (_placeReports.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Badge(count: _placeReports.length),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(cs),
          _buildPlacesTab(cs),
        ],
      ),
    );
  }

  Widget _buildPostsTab(ColorScheme cs) {
    if (_loadingPosts) return const Center(child: CircularProgressIndicator());
    if (_postError != null) return _ErrorView(msg: _postError!, onRetry: _loadPosts);
    if (_postReports.isEmpty) return const _EmptyView(label: 'No reported posts.');
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _postReports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ReportCard(
          report: _postReports[i],
          api: widget.api,
          timeAgo: _timeAgo,
          onDeletePost: () => _deletePost(_postReports[i]),
          onDismiss: () => _dismissPost(_postReports[i]),
        ),
      ),
    );
  }

  Widget _buildPlacesTab(ColorScheme cs) {
    if (_loadingPlaces) return const Center(child: CircularProgressIndicator());
    if (_placeError != null) return _ErrorView(msg: _placeError!, onRetry: _loadPlaces);
    if (_placeReports.isEmpty) return const _EmptyView(label: 'No reported places.');
    return RefreshIndicator(
      onRefresh: _loadPlaces,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _placeReports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PlaceReportCard(
          report: _placeReports[i],
          timeAgo: _timeAgo,
          onDelete: () => _deletePlace(_placeReports[i]),
          onDismiss: () => _dismissPlaceReports(_placeReports[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: cs.onError, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String label;
  const _EmptyView({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_outlined, size: 64, color: cs.outlineVariant),
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: cs.error),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Reported post card
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
    final imageUrl = report.imageUrl != null ? '${api.baseUrl}${report.imageUrl}' : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag_rounded, color: cs.error, size: 18),
              const SizedBox(width: 6),
              Text(
                '${report.reportCount} report${report.reportCount > 1 ? 's' : ''}',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text('· first ${timeAgo(report.firstReportedAt)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ]),
            const Divider(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  report.author.isNotEmpty ? report.author[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(report.author, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(report.content, style: Theme.of(context).textTheme.bodyMedium),
            if (imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl,
                    height: 140, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: cs.surfaceContainerHighest,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant)),
                    )),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
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
                  style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                  onPressed: onDeletePost,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete Post'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reported place card
// ─────────────────────────────────────────────
class _PlaceReportCard extends StatelessWidget {
  final PlaceReport report;
  final String Function(DateTime) timeAgo;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const _PlaceReportCard({
    required this.report,
    required this.timeAgo,
    required this.onDelete,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag_rounded, color: cs.error, size: 18),
              const SizedBox(width: 6),
              Text(
                '${report.reportCount} report${report.reportCount > 1 ? 's' : ''}',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text('· first ${timeAgo(report.firstReportedAt)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ]),
            const Divider(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.place_rounded, size: 18, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    report.name.isEmpty ? 'Unnamed place' : report.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${report.category}  •  ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
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
                  style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete Place'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

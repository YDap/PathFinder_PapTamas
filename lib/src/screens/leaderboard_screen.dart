import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/places_api.dart';
import '../services/level_service.dart';
import 'stats_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  final PlacesApi api;
  const LeaderboardScreen({super.key, required this.api});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _all = [];
  List<LeaderboardEntry> _filtered = [];
  Set<String> _friendIds = {};
  Set<String> _sentIds = {};
  bool _loading = true;
  String? _error;
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.fetchLeaderboard(),
        widget.api.getFriends(),
      ]);
      final entries = results[0] as List<LeaderboardEntry>;
      final friends = results[1] as List<FriendUser>;
      if (mounted) {
        setState(() {
          _all      = entries;
          _filtered = entries;
          _friendIds = friends.map((f) => f.userId).toSet();
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((e) => e.displayName.toLowerCase().contains(q)).toList();
    });
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _searchFocus.requestFocus();
    } else {
      _searchCtrl.clear();
      _searchFocus.unfocus();
    }
  }

  Future<void> _addFriend(String userId) async {
    try {
      await widget.api.sendFriendRequest(userId);
      if (mounted) setState(() => _sentIds.add(userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search players…',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                ),
                style: Theme.of(context).textTheme.titleMedium,
              )
            : const Text('🏆 Leaderboard'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _searching ? 'Cancel' : 'Search',
            onPressed: _toggleSearch,
          ),
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded, size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No players match "${_searchCtrl.text}"',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _EntryTile(
                        entry:     _filtered[i],
                        api:       widget.api,
                        currentId: _currentUid,
                        isFriend:  _friendIds.contains(_filtered[i].userId),
                        isSent:    _sentIds.contains(_filtered[i].userId),
                        onAdd:     () => _addFriend(_filtered[i].userId),
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────
// Single leaderboard row
// ─────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final PlacesApi api;
  final String currentId;
  final bool isFriend;
  final bool isSent;
  final VoidCallback onAdd;

  const _EntryTile({
    required this.entry,
    required this.api,
    required this.currentId,
    required this.isFriend,
    required this.isSent,
    required this.onAdd,
  });

  static const _gold   = Color(0xFFFFD700);
  static const _silver = Color(0xFF607D8B); // blue-grey — distinct from card bg
  static const _bronze = Color(0xFFCD7F32);

  Color _rankColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return const Color(0xFF9E9E9E);
  }

  double _rankSize(int rank) => rank <= 3 ? 42 : 34;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final rc    = _rankColor(entry.rank);
    final level = levelFromXp(entry.totalXp);
    final title = levelTitle(level);
    final isMe  = entry.userId == currentId;
    final avatarUrl = entry.profileImageUrl != null
        ? '${api.baseUrl}${entry.profileImageUrl}'
        : null;

    // Subtle gold/silver/bronze card tint for top 3
    Color? cardColor;
    if (entry.rank == 1) cardColor = _gold.withValues(alpha: 0.07);
    if (entry.rank == 2) cardColor = _silver.withValues(alpha: 0.09);
    if (entry.rank == 3) cardColor = _bronze.withValues(alpha: 0.07);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsScreen(
              api: api,
              userId: entry.userId,
              displayName: entry.displayName,
              profileImageUrl: avatarUrl,
            ),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Rank badge ────────────────────────────────────
            SizedBox(
              width: 46,
              child: Center(
                child: Container(
                  width: _rankSize(entry.rank),
                  height: _rankSize(entry.rank),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rc.withValues(alpha: entry.rank <= 3 ? 0.15 : 0.1),
                    border: Border.all(
                      color: rc,
                      width: entry.rank <= 3 ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.rank}',
                      style: TextStyle(
                        color: rc,
                        fontWeight: FontWeight.w900,
                        fontSize: entry.rank <= 3 ? 16 : 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Avatar ────────────────────────────────────────
            CircleAvatar(
              radius: 22,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: cs.primaryContainer,
              child: avatarUrl == null
                  ? Text(
                      entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // ── Name + level info ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: entry.rank <= 3
                              ? (entry.rank == 1 ? const Color(0xFFB8860B) :
                                 entry.rank == 2 ? const Color(0xFF37474F) :
                                 const Color(0xFF8B4513))
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('You',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'Lv.$level · $title · ${entry.totalXp} XP',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Friend action ─────────────────────────────────
            if (!isMe)
              isFriend
                  ? Tooltip(
                      message: 'Already friends',
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Icon(Icons.person_rounded,
                            size: 18, color: Colors.green.shade600),
                      ),
                    )
                  : isSent
                      ? Tooltip(
                          message: 'Request sent',
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.surfaceContainerHighest,
                            ),
                            child: Icon(Icons.hourglass_top_rounded,
                                size: 18, color: cs.onSurfaceVariant),
                          ),
                        )
                      : IconButton(
                          onPressed: onAdd,
                          tooltip: 'Add friend',
                          icon: const Icon(Icons.person_add_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                          ),
                        ),
          ],
        ),
        ),
      ),
    );
  }
}

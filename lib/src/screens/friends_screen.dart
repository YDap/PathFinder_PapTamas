import 'package:flutter/material.dart';
import '../services/places_api.dart';
import 'stats_screen.dart';

class FriendsScreen extends StatefulWidget {
  final PlacesApi api;

  const FriendsScreen({super.key, required this.api});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<FriendUser> _friends = [];
  List<FriendUser> _requests = [];
  List<FriendUser> _searchResults = [];

  bool _loadingFriends = true;
  bool _loadingRequests = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
    _loadRequests();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    try {
      final friends = await widget.api.getFriends();
      if (mounted) setState(() => _friends = friends);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final requests = await widget.api.getFriendRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _doSearch(q);
  }

  Future<void> _doSearch(String q) async {
    setState(() => _searching = true);
    try {
      final results = await widget.api.searchUsers(q);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(FriendUser user) async {
    try {
      await widget.api.sendFriendRequest(user.userId);
      if (!mounted) return;
      setState(() {
        final idx = _searchResults.indexWhere((u) => u.userId == user.userId);
        if (idx != -1) {
          _searchResults[idx] = FriendUser(
            userId: user.userId,
            displayName: user.displayName,
            email: user.email,
            profileImageUrl: user.profileImageUrl,
            friendshipStatus: 'sent',
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${user.label}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _acceptRequest(FriendUser user) async {
    try {
      await widget.api.acceptFriendRequest(user.userId);
      if (!mounted) return;
      setState(() => _requests.removeWhere((u) => u.userId == user.userId));
      await _loadFriends();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.label} is now your friend!')),
      );
    } catch (_) {}
  }

  Future<void> _declineRequest(FriendUser user) async {
    try {
      await widget.api.removeFriend(user.userId);
      if (!mounted) return;
      setState(() => _requests.removeWhere((u) => u.userId == user.userId));
    } catch (_) {}
  }

  Future<void> _removeFriend(FriendUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${user.label} from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.removeFriend(user.userId);
      if (!mounted) return;
      setState(() => _friends.removeWhere((u) => u.userId == user.userId));
    } catch (_) {}
  }

  void _openProfile(FriendUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          api: widget.api,
          userId: user.userId,
          displayName: user.label,
          profileImageUrl: user.profileImageUrl != null
              ? '${widget.api.baseUrl}${user.profileImageUrl}'
              : null,
        ),
      ),
    );
  }

  Widget _avatar(FriendUser user, {double radius = 22}) {
    final cs = Theme.of(context).colorScheme;
    final url = user.profileImageUrl != null
        ? '${widget.api.baseUrl}${user.profileImageUrl}'
        : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              user.label.isNotEmpty ? user.label[0].toUpperCase() : '?',
              style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.people_rounded), text: 'Friends'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_rounded, size: 18),
                  const SizedBox(width: 4),
                  const Text('Requests'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.search_rounded), text: 'Search'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Friends list ──────────────────────────
          _loadingFriends
              ? const Center(child: CircularProgressIndicator())
              : _friends.isEmpty
                  ? _empty('No friends yet.\nSearch for people in the Search tab!')
                  : RefreshIndicator(
                      onRefresh: _loadFriends,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _friends.length,
                        itemBuilder: (_, i) {
                          final u = _friends[i];
                          return ListTile(
                            leading: _avatar(u),
                            title: Text(u.label),
                            subtitle: u.email != null ? Text(u.email!) : null,
                            onTap: () => _openProfile(u),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_remove_rounded),
                              tooltip: 'Remove friend',
                              onPressed: () => _removeFriend(u),
                            ),
                          );
                        },
                      ),
                    ),

          // ── Requests ─────────────────────────────
          _loadingRequests
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
                  ? _empty('No pending friend requests.')
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) {
                          final u = _requests[i];
                          return ListTile(
                            leading: _avatar(u),
                            title: Text(u.label),
                            subtitle: u.email != null ? Text(u.email!) : null,
                            onTap: () => _openProfile(u),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                  tooltip: 'Accept',
                                  onPressed: () => _acceptRequest(u),
                                ),
                                IconButton(
                                  icon: Icon(Icons.cancel_rounded,
                                      color: Theme.of(context).colorScheme.error),
                                  tooltip: 'Decline',
                                  onPressed: () => _declineRequest(u),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

          // ── Search ────────────────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? _empty(_searchController.text.length < 2
                            ? 'Type at least 2 characters to search.'
                            : 'No users found.')
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (_, i) {
                              final u = _searchResults[i];
                              return ListTile(
                                leading: _avatar(u),
                                title: Text(u.label),
                                subtitle: u.email != null ? Text(u.email!) : null,
                                onTap: () => _openProfile(u),
                                trailing: _searchAction(u),
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchAction(FriendUser u) {
    switch (u.friendshipStatus) {
      case 'friend':
        return const Chip(label: Text('Friends'));
      case 'sent':
        return const Chip(label: Text('Sent'));
      case 'incoming':
        return FilledButton(
          onPressed: () => _acceptRequest(u),
          child: const Text('Accept'),
        );
      default:
        return IconButton(
          icon: const Icon(Icons.person_add_rounded),
          tooltip: 'Add friend',
          onPressed: () => _sendRequest(u),
        );
    }
  }

  Widget _empty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg, textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

import 'package:flutter/material.dart';
import '../services/places_api.dart';
import '../services/level_service.dart';

class StatsScreen extends StatefulWidget {
  final PlacesApi api;

  /// When set, the screen shows another user's profile and badges
  /// (read-only) instead of the current user's stats.
  final String? userId;
  final String? displayName;
  final String? profileImageUrl;

  const StatsScreen({
    super.key,
    required this.api,
    this.userId,
    this.displayName,
    this.profileImageUrl,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  UserStats? _stats;
  String? _displayName;
  String? _profileImageUrl;
  bool _loading = true;
  String? _error;

  bool get _isOtherUser => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _displayName = widget.displayName;
    _profileImageUrl = widget.profileImageUrl;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isOtherUser) {
        final p = await widget.api.fetchUserStats(widget.userId!);
        if (mounted) {
          setState(() {
            _stats = p.stats;
            _displayName = p.displayName;
            if (p.profileImageUrl != null) {
              _profileImageUrl = '${widget.api.baseUrl}${p.profileImageUrl}';
            }
            _loading = false;
          });
        }
      } else {
        final s = await widget.api.fetchMyStats();
        if (mounted) setState(() { _stats = s; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── Level progression sheet ────────────────────────────────
  void _showLevelProgression(BuildContext ctx, int currentLevel) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtl) {
          final cs = Theme.of(ctx).colorScheme;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999)),
                ),
                Expanded(child: Text('All Level Titles',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtl,
                itemCount: 20,
                itemBuilder: (_, i) {
                  final lv = i + 1;
                  final isCurrent = lv == currentLevel;
                  final xpNeeded = xpForLevel(lv);
                  final xpNext = xpForLevel(lv + 1);
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isCurrent ? cs.primary : cs.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('$lv',
                          style: TextStyle(
                            color: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ))),
                    ),
                    title: Text(levelTitle(lv),
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                          color: isCurrent ? cs.primary : null,
                        )),
                    subtitle: Text('$xpNeeded XP — ${xpNext - xpNeeded} XP to next',
                        style: const TextStyle(fontSize: 12)),
                    trailing: isCurrent
                        ? Chip(
                            label: Text(_isOtherUser ? 'Current' : 'You',
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor: cs.primaryContainer,
                            padding: EdgeInsets.zero,
                          )
                        : null,
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── Badge info dialog ──────────────────────────────────────
  void _showBadgeInfo(BuildContext ctx, BadgeDef def, List<int> thresholds, String description) {
    showDialog(
      context: ctx,
      builder: (d) {
        final cs = Theme.of(d).colorScheme;
        final tiers = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.platinum];
        return AlertDialog(
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: def.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(def.icon, color: def.color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(def.name),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 16),
              ...List.generate(4, (i) {
                final t = tiers[i];
                final tc = tierColors[t]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tc.withValues(alpha: 0.15),
                        border: Border.all(color: tc, width: 1.5),
                      ),
                      child: Center(child: Text(tierLabels[t]![0],
                          style: TextStyle(
                            color: t == BadgeTier.gold ? const Color(0xFFB8860B) : tc,
                            fontWeight: FontWeight.w900, fontSize: 12))),
                    ),
                    const SizedBox(width: 10),
                    Text(tierLabels[t]!,
                        style: TextStyle(fontWeight: FontWeight.w600, color: tc)),
                    const Spacer(),
                    Text('${thresholds[i]} visits',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ]),
                );
              }),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('Got it')),
          ],
        );
      },
    );
  }

  void _showAchievInfo(BuildContext ctx, BadgeDef def, List thresholds, String unit, String description) {
    showDialog(
      context: ctx,
      builder: (d) {
        final cs = Theme.of(d).colorScheme;
        final tiers = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold, BadgeTier.platinum];
        return AlertDialog(
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: def.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(def.icon, color: def.color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(def.name),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 16),
              ...List.generate(4, (i) {
                final t = tiers[i];
                final tc = tierColors[t]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tc.withValues(alpha: 0.15),
                        border: Border.all(color: tc, width: 1.5),
                      ),
                      child: Center(child: Text(tierLabels[t]![0],
                          style: TextStyle(
                            color: t == BadgeTier.gold ? const Color(0xFFB8860B) : tc,
                            fontWeight: FontWeight.w900, fontSize: 12))),
                    ),
                    const SizedBox(width: 10),
                    Text(tierLabels[t]!, style: TextStyle(fontWeight: FontWeight.w600, color: tc)),
                    const Spacer(),
                    Text('${thresholds[i]} $unit',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ]),
                );
              }),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(d), child: const Text('Got it')),
          ],
        );
      },
    );
  }

  // ── Main content ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOtherUser
            ? (_displayName ?? 'Profile')
            : 'Stats & Badges'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
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
              : _buildContent(context, _stats!, cs),
    );
  }

  Widget _buildContent(BuildContext ctx, UserStats s, ColorScheme cs) {
    final xp = computeXp(s);
    final level = levelFromXp(xp);
    final xpStart = xpForLevel(level);
    final xpEnd = xpForLevel(level + 1);
    final levelProgress = ((xp - xpStart) / (xpEnd - xpStart)).clamp(0.0, 1.0);
    final distinctNat = naturalCategories.where((c) => (s.visitsByCategory[c] ?? 0) > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

        // ── Profile header (only when viewing another user) ───
        if (_isOtherUser) ...[
          Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: cs.primaryContainer,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _profileImageUrl == null
                  ? Text(
                      (_displayName?.isNotEmpty ?? false)
                          ? _displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_displayName ?? 'Anonymous',
                    style: Theme.of(ctx).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('🥾 Explorer profile',
                    style: Theme.of(ctx).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
        ],

        // ── Level card (tappable → shows all levels) ──────────
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showLevelProgression(ctx, level),
            child: Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        child: Center(child: Text('$level',
                            style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w900, fontSize: 20))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(levelTitle(level), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.onPrimaryContainer)),
                          Text('$xp XP total', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withValues(alpha: 0.75))),
                        ],
                      )),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Level ${level + 1}', style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
                        Text('${xpEnd - xp} XP to go', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                      ]),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: levelProgress, minHeight: 10,
                        backgroundColor: cs.primary.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('$xpStart XP', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer.withValues(alpha: 0.6))),
                      Text('${xp - xpStart} / ${xpEnd - xpStart} XP',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                      Text('$xpEnd XP', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer.withValues(alpha: 0.6))),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('Tap to view all level titles →',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                              color: cs.onPrimaryContainer.withValues(alpha: 0.65))),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Summary row ────────────────────────────────────────
        Row(children: [
          _StatCard(icon: Icons.route_rounded,  color: const Color(0xFFFF7043),
              value: s.totalKm >= 1000 ? '${(s.totalKm / 1000).toStringAsFixed(1)}k' : s.totalKm.toStringAsFixed(1),
              label: 'km traveled'),
          const SizedBox(width: 10),
          _StatCard(icon: Icons.place_rounded,  color: const Color(0xFF7E57C2),
              value: '${s.totalVisits}', label: 'places visited'),
          const SizedBox(width: 10),
          _StatCard(icon: Icons.article_rounded, color: const Color(0xFF66BB6A),
              value: '${s.postsCount}', label: 'posts published'),
        ]),
        const SizedBox(height: 24),

        // ── Place badges ────────────────────────────────────────
        _sectionHeader(ctx, Icons.landscape, 'Place Badges',
            'Navigate to and reach a place to count it. Tap ⓘ on any badge for requirements.'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78,
          children: placeBadgeDefs.map((def) {
            final count = s.visitsByCategory[def.key] ?? 0;
            final t = badgeTier(count, placeThresholds);
            final p = badgeProgress(count, placeThresholds);
            return _BadgeCard(
              name: def.name, icon: def.icon, iconColor: def.color,
              tier: t, progressFrac: p.frac, progressLabel: p.label,
              thresholdLabel: nextTierLabel(t, placeThresholds),
              onInfo: () => _showBadgeInfo(ctx, def, placeThresholds,
                  'Navigate to ${def.name == 'Peak Climber' ? 'peaks' : def.name == 'Lake Explorer' ? 'lakes' : def.name == 'Cave Diver' ? 'caves' : def.name == 'Ruin Hunter' ? 'ruins' : def.name == 'Spring Seeker' ? 'springs' : 'viewpoints'} and reach the destination to count each visit.'),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Achievement badges ──────────────────────────────────
        _sectionHeader(ctx, Icons.emoji_events_rounded, 'Achievements',
            'Earned through navigation, posts and exploration. Tap ⓘ for requirements.'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78,
          children: [
            () {
              final def = achievBadgeDefs[0];
              final t = badgeTierD(s.totalKm, kmThresholds);
              final p = badgeProgressD(s.totalKm, kmThresholds);
              return _BadgeCard(name: def.name, icon: def.icon, iconColor: def.color,
                  tier: t, progressFrac: p.frac, progressLabel: p.label,
                  thresholdLabel: nextTierLabelD(t, kmThresholds, 'km'),
                  onInfo: () => _showAchievInfo(ctx, def, [10, 50, 150, 500], 'km',
                      'Total kilometers traveled across all your navigation sessions.'));
            }(),
            () {
              final def = achievBadgeDefs[1];
              final t = badgeTier(s.postsCount, postThresholds);
              final p = badgeProgress(s.postsCount, postThresholds);
              return _BadgeCard(name: def.name, icon: def.icon, iconColor: def.color,
                  tier: t, progressFrac: p.frac, progressLabel: p.label,
                  thresholdLabel: nextTierLabel(t, postThresholds),
                  onInfo: () => _showAchievInfo(ctx, def, postThresholds, 'posts',
                      'Total posts published at any location.'));
            }(),
            () {
              final def = achievBadgeDefs[2];
              final t = badgeTier(distinctNat, explorerThresholds);
              final p = badgeProgress(distinctNat, explorerThresholds);
              return _BadgeCard(name: def.name, icon: def.icon, iconColor: def.color,
                  tier: t, progressFrac: p.frac,
                  progressLabel: '$distinctNat / ${_nextT(t, explorerThresholds)} categories',
                  thresholdLabel: nextTierLabel(t, explorerThresholds),
                  onInfo: () => _showAchievInfo(ctx, def, explorerThresholds, 'categories',
                      'Number of distinct natural place types visited (peak, lake, cave, ruin, spring, viewpoint).'));
            }(),
            () {
              final def = achievBadgeDefs[3];
              final t = badgeTier(s.totalNavigations, navThresholds);
              final p = badgeProgress(s.totalNavigations, navThresholds);
              return _BadgeCard(name: def.name, icon: def.icon, iconColor: def.color,
                  tier: t, progressFrac: p.frac, progressLabel: p.label,
                  thresholdLabel: nextTierLabel(t, navThresholds),
                  onInfo: () => _showAchievInfo(ctx, def, navThresholds, 'navigations',
                      'Total number of navigation sessions completed (destination reached or manually stopped).'));
            }(),
          ],
        ),
        const SizedBox(height: 16),

        // ── XP breakdown ───────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('XP Breakdown',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _XpRow('Places visited', '${s.totalVisits} × 10', s.totalVisits * 10),
              _XpRow('km traveled', '${s.totalKm.toStringAsFixed(1)} × 2', (s.totalKm * 2).round()),
              _XpRow('Posts published', '${s.postsCount} × 25', s.postsCount * 25),
              _XpRow('Badge bonuses', 'unlocking tiers',
                  xp - s.totalVisits * 10 - (s.totalKm * 2).round() - s.postsCount * 25),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('$xp XP', style: TextStyle(fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.primary)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Tier legend ─────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Place Badge Thresholds',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _TierChip(tier: BadgeTier.bronze,   label: '5+'),
                _TierChip(tier: BadgeTier.silver,   label: '15+'),
                _TierChip(tier: BadgeTier.gold,     label: '25+'),
                _TierChip(tier: BadgeTier.platinum, label: '40+'),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

  int _nextT(BadgeTier t, List<int> thresholds) {
    if (t == BadgeTier.platinum) return thresholds[3];
    if (t == BadgeTier.gold)     return thresholds[3];
    if (t == BadgeTier.silver)   return thresholds[2];
    if (t == BadgeTier.bronze)   return thresholds[1];
    return thresholds[0];
  }

  Widget _sectionHeader(BuildContext ctx, IconData icon, String title, String subtitle) {
    final cs = Theme.of(ctx).colorScheme;
    return Row(children: [
      Icon(icon, color: cs.primary, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ])),
    ]);
  }
}

// ─────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────

class _XpRow extends StatelessWidget {
  final String label, detail;
  final int xp;
  const _XpRow(this.label, this.detail, this.xp);

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(detail, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(width: 12),
        Text('+$xp XP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String name, progressLabel, thresholdLabel;
  final IconData icon;
  final Color iconColor;
  final BadgeTier tier;
  final double progressFrac;
  final VoidCallback? onInfo;

  const _BadgeCard({
    required this.name, required this.icon, required this.iconColor,
    required this.tier, required this.progressFrac, required this.progressLabel,
    required this.thresholdLabel, this.onInfo,
  });

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final tc = tierColors[tier]!;
    final earned = tier != BadgeTier.locked;

    return Card(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: earned ? iconColor.withValues(alpha: 0.12) : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(color: tc, width: earned ? 3 : 1.5),
                  ),
                  child: Icon(icon, size: 30, color: earned ? iconColor : cs.outlineVariant),
                ),
                if (earned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(8)),
                    child: Text(tierLabels[tier]![0],
                        style: TextStyle(
                          color: tier == BadgeTier.gold ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
              ]),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: tc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(tierLabels[tier]!.toUpperCase(),
                    style: TextStyle(
                      color: tier == BadgeTier.gold ? const Color(0xFFB8860B) : tc,
                      fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.8)),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressFrac, minHeight: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(tc),
                ),
              ),
              const SizedBox(height: 4),
              Text(progressLabel, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(thresholdLabel,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          // ⓘ info button — top right
          if (onInfo != null)
            Positioned(
              top: 4, right: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onInfo,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.info_outline_rounded,
                      size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final BadgeTier tier;
  final String label;
  const _TierChip({required this.tier, required this.label});

  @override
  Widget build(BuildContext ctx) {
    final tc = tierColors[tier]!;
    return Column(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tc.withValues(alpha: 0.15),
          border: Border.all(color: tc, width: 2),
        ),
        child: Center(child: Text(tierLabels[tier]![0],
            style: TextStyle(
              color: tier == BadgeTier.gold ? const Color(0xFFB8860B) : tc,
              fontWeight: FontWeight.w900, fontSize: 13))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: tc, fontWeight: FontWeight.w600)),
    ]);
  }
}

import 'package:flutter/material.dart';
import '../services/places_api.dart';
import '../services/level_service.dart';

class StatsScreen extends StatefulWidget {
  final PlacesApi api;
  const StatsScreen({super.key, required this.api});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  UserStats? _stats;
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
      final s = await widget.api.fetchMyStats();
      if (mounted) setState(() { _stats = s; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Badges'),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
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
        // ── Level card ────────────────────────────────────────
        Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(levelTitle(level),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: cs.onPrimaryContainer,
                              )),
                          Text('$xp XP total',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                              )),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Level ${level + 1}',
                            style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
                        Text('${xpEnd - xp} XP to go',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    minHeight: 10,
                    backgroundColor: cs.primary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$xpStart XP', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer.withValues(alpha: 0.6))),
                    Text('${xp - xpStart} / ${xpEnd - xpStart} XP',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                    Text('$xpEnd XP', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer.withValues(alpha: 0.6))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Summary row ────────────────────────────────────────
        Row(
          children: [
            _StatCard(icon: Icons.route_rounded,  color: const Color(0xFFFF7043),
                value: s.totalKm >= 1000 ? '${(s.totalKm / 1000).toStringAsFixed(1)}k' : s.totalKm.toStringAsFixed(1),
                label: 'km traveled'),
            const SizedBox(width: 10),
            _StatCard(icon: Icons.place_rounded,  color: const Color(0xFF7E57C2),
                value: '${s.totalVisits}', label: 'places visited'),
            const SizedBox(width: 10),
            _StatCard(icon: Icons.article_rounded, color: const Color(0xFF66BB6A),
                value: '${s.postsCount}', label: 'posts published'),
          ],
        ),
        const SizedBox(height: 24),

        // ── Place badges ────────────────────────────────────────
        _sectionHeader(ctx, Icons.landscape, 'Place Badges', 'Navigate to a place and reach it to earn these'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8,
          children: placeBadgeDefs.map((def) {
            final count = s.visitsByCategory[def.key] ?? 0;
            final t = badgeTier(count, placeThresholds);
            final p = badgeProgress(count, placeThresholds);
            return _BadgeCard(
              name: def.name, icon: def.icon, iconColor: def.color, tier: t,
              progressFrac: p.frac, progressLabel: p.label,
              thresholdLabel: nextTierLabel(t, placeThresholds),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Achievement badges ──────────────────────────────────
        _sectionHeader(ctx, Icons.emoji_events_rounded, 'Achievements', 'Earned through navigation, posts and exploration'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8,
          children: [
            () { final t = badgeTierD(s.totalKm, kmThresholds); final p = badgeProgressD(s.totalKm, kmThresholds);
              return _BadgeCard(name: 'Long Hauler', icon: Icons.route_rounded, iconColor: const Color(0xFFFF7043),
                tier: t, progressFrac: p.frac, progressLabel: p.label, thresholdLabel: nextTierLabelD(t, kmThresholds, 'km')); }(),
            () { final t = badgeTier(s.postsCount, postThresholds); final p = badgeProgress(s.postsCount, postThresholds);
              return _BadgeCard(name: 'Storyteller', icon: Icons.auto_stories_rounded, iconColor: const Color(0xFF66BB6A),
                tier: t, progressFrac: p.frac, progressLabel: p.label, thresholdLabel: nextTierLabel(t, postThresholds)); }(),
            () { final t = badgeTier(distinctNat, explorerThresholds); final p = badgeProgress(distinctNat, explorerThresholds);
              return _BadgeCard(name: 'True Explorer', icon: Icons.explore_rounded, iconColor: const Color(0xFF26C6DA),
                tier: t, progressFrac: p.frac, progressLabel: '$distinctNat / ${_nextTarget(t, explorerThresholds)} categories',
                thresholdLabel: nextTierLabel(t, explorerThresholds)); }(),
            () { final t = badgeTier(s.totalNavigations, navThresholds); final p = badgeProgress(s.totalNavigations, navThresholds);
              return _BadgeCard(name: 'Road Warrior', icon: Icons.navigation_rounded, iconColor: const Color(0xFF42A5F5),
                tier: t, progressFrac: p.frac, progressLabel: p.label, thresholdLabel: nextTierLabel(t, navThresholds)); }(),
          ],
        ),
        const SizedBox(height: 16),

        // ── XP breakdown ───────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('XP Breakdown', style: Theme.of(ctx).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _XpRow('Places visited', '${s.totalVisits} × 10', s.totalVisits * 10),
                _XpRow('km traveled', '${s.totalKm.toStringAsFixed(1)} × 2', (s.totalKm * 2).round()),
                _XpRow('Posts published', '${s.postsCount} × 25', s.postsCount * 25),
                _XpRow('Badge bonuses', 'unlocking tiers', xp - s.totalVisits * 10 - (s.totalKm * 2).round() - s.postsCount * 25),
                const Divider(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('$xp XP', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.primary)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Tier legend ─────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tier Thresholds (place badges)', style: Theme.of(ctx).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _TierChip(tier: BadgeTier.bronze,   label: '5+'),
                  _TierChip(tier: BadgeTier.silver,   label: '15+'),
                  _TierChip(tier: BadgeTier.gold,     label: '25+'),
                  _TierChip(tier: BadgeTier.platinum, label: '40+'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _nextTarget(BadgeTier t, List<int> thresholds) {
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
            Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
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

  const _BadgeCard({
    required this.name, required this.icon, required this.iconColor,
    required this.tier, required this.progressFrac, required this.progressLabel,
    required this.thresholdLabel,
  });

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final tc = tierColors[tier]!;
    final earned = tier != BadgeTier.locked;

    return Card(
      child: Padding(
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
              color: tc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
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

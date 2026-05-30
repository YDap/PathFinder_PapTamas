import 'package:flutter/material.dart';
import '../services/places_api.dart';

// ─────────────────────────────────────────────
// Tier system
// ─────────────────────────────────────────────
enum BadgeTier { locked, bronze, silver, gold, platinum }

const _tierColors = <BadgeTier, Color>{
  BadgeTier.locked:   Color(0xFF9E9E9E),
  BadgeTier.bronze:   Color(0xFFCD7F32),
  BadgeTier.silver:   Color(0xFFB0B7C3),
  BadgeTier.gold:     Color(0xFFFFD700),
  BadgeTier.platinum: Color(0xFF00BCD4),
};

const _tierLabels = <BadgeTier, String>{
  BadgeTier.locked:   'Locked',
  BadgeTier.bronze:   'Bronze',
  BadgeTier.silver:   'Silver',
  BadgeTier.gold:     'Gold',
  BadgeTier.platinum: 'Platinum',
};

// Thresholds: [bronze, silver, gold, platinum]
const _placeT  = [5, 15, 25, 40];
const _postT   = [5, 15, 25, 50];
const _explorerT = [2, 4, 5, 6]; // distinct natural categories visited
const _navT    = [5, 15, 30, 60];
final  _kmT    = [10.0, 50.0, 150.0, 500.0];

BadgeTier _tier(int count, List<int> t) {
  if (count >= t[3]) return BadgeTier.platinum;
  if (count >= t[2]) return BadgeTier.gold;
  if (count >= t[1]) return BadgeTier.silver;
  if (count >= t[0]) return BadgeTier.bronze;
  return BadgeTier.locked;
}

BadgeTier _tierD(double v, List<double> t) {
  if (v >= t[3]) return BadgeTier.platinum;
  if (v >= t[2]) return BadgeTier.gold;
  if (v >= t[1]) return BadgeTier.silver;
  if (v >= t[0]) return BadgeTier.bronze;
  return BadgeTier.locked;
}

({double frac, String label}) _prog(int count, List<int> t) {
  if (count >= t[3]) return (frac: 1.0, label: '$count — MAX');
  int prev = 0, next = t[0];
  if (count >= t[2]) { prev = t[2]; next = t[3]; }
  else if (count >= t[1]) { prev = t[1]; next = t[2]; }
  else if (count >= t[0]) { prev = t[0]; next = t[1]; }
  return (
    frac: ((count - prev) / (next - prev)).clamp(0.0, 1.0),
    label: '$count / $next',
  );
}

({double frac, String label}) _progD(double v, List<double> t) {
  if (v >= t[3]) return (frac: 1.0, label: '${v.toStringAsFixed(1)} km — MAX');
  double prev = 0, next = t[0];
  if (v >= t[2]) { prev = t[2]; next = t[3]; }
  else if (v >= t[1]) { prev = t[1]; next = t[2]; }
  else if (v >= t[0]) { prev = t[0]; next = t[1]; }
  return (
    frac: ((v - prev) / (next - prev)).clamp(0.0, 1.0),
    label: '${v.toStringAsFixed(1)} / ${next.toStringAsFixed(0)} km',
  );
}

// ─────────────────────────────────────────────
// Badge definitions
// ─────────────────────────────────────────────
class _Def {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  const _Def(this.key, this.name, this.icon, this.color);
}

const _naturalCategories = ['peak', 'lake', 'cave', 'ruin', 'spring', 'viewpoint'];

const _placeDefs = [
  _Def('peak',      'Peak Climber',  Icons.landscape,          Color(0xFF7E57C2)),
  _Def('lake',      'Lake Explorer', Icons.water_rounded,       Color(0xFF42A5F5)),
  _Def('cave',      'Cave Diver',    Icons.terrain,             Color(0xFF8D6E63)),
  _Def('ruin',      'Ruin Hunter',   Icons.account_balance,     Color(0xFFEF5350)),
  _Def('spring',    'Spring Seeker', Icons.water_drop,          Color(0xFF26A69A)),
  _Def('viewpoint', 'Vista Chaser',  Icons.visibility,          Color(0xFF5C6BC0)),
];

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
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
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
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

  Widget _buildContent(BuildContext context, UserStats s, ColorScheme cs) {
    final distinctNatural = _naturalCategories
        .where((c) => (s.visitsByCategory[c] ?? 0) > 0)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Summary row ────────────────────────────────────────
        Row(
          children: [
            _StatCard(
              icon: Icons.route_rounded,
              color: const Color(0xFFFF7043),
              value: s.totalKm >= 1000
                  ? '${(s.totalKm / 1000).toStringAsFixed(1)}k'
                  : s.totalKm.toStringAsFixed(1),
              label: 'km traveled',
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: Icons.place_rounded,
              color: const Color(0xFF7E57C2),
              value: '${s.totalVisits}',
              label: 'places visited',
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: Icons.article_rounded,
              color: const Color(0xFF66BB6A),
              value: '${s.postsCount}',
              label: 'posts published',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Place badges ────────────────────────────────────────
        _sectionHeader(context, Icons.landscape, 'Place Badges',
            'Navigate to a place and reach it to earn these'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: _placeDefs.map((def) {
            final count = s.visitsByCategory[def.key] ?? 0;
            final t = _tier(count, _placeT);
            final p = _prog(count, _placeT);
            return _BadgeCard(
              name: def.name,
              icon: def.icon,
              iconColor: def.color,
              tier: t,
              progressFrac: p.frac,
              progressLabel: p.label,
              thresholdLabel: _nextTierLabel(t, _placeT),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // ── Achievement badges ──────────────────────────────────
        _sectionHeader(context, Icons.emoji_events_rounded, 'Achievements',
            'Earned through navigation, posts and exploration'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: [
            // Long Hauler — km
            () {
              final t = _tierD(s.totalKm, _kmT);
              final p = _progD(s.totalKm, _kmT);
              return _BadgeCard(
                name: 'Long Hauler',
                icon: Icons.route_rounded,
                iconColor: const Color(0xFFFF7043),
                tier: t,
                progressFrac: p.frac,
                progressLabel: p.label,
                thresholdLabel: _nextTierLabelD(t, _kmT, 'km'),
              );
            }(),
            // Storyteller — posts
            () {
              final t = _tier(s.postsCount, _postT);
              final p = _prog(s.postsCount, _postT);
              return _BadgeCard(
                name: 'Storyteller',
                icon: Icons.auto_stories_rounded,
                iconColor: const Color(0xFF66BB6A),
                tier: t,
                progressFrac: p.frac,
                progressLabel: p.label,
                thresholdLabel: _nextTierLabel(t, _postT),
              );
            }(),
            // True Explorer — distinct natural categories
            () {
              final t = _tier(distinctNatural, _explorerT);
              final p = _prog(distinctNatural, _explorerT);
              return _BadgeCard(
                name: 'True Explorer',
                icon: Icons.explore_rounded,
                iconColor: const Color(0xFF26C6DA),
                tier: t,
                progressFrac: p.frac,
                progressLabel: '${distinctNatural} / ${_explorerT[BadgeTier.values.indexOf(t) == 0 ? 0 : BadgeTier.values.indexOf(t) - 1 >= 4 ? 3 : BadgeTier.values.indexOf(t) - 1]} categories',
                thresholdLabel: _nextTierLabel(t, _explorerT),
              );
            }(),
            // Road Warrior — navigations
            () {
              final t = _tier(s.totalNavigations, _navT);
              final p = _prog(s.totalNavigations, _navT);
              return _BadgeCard(
                name: 'Road Warrior',
                icon: Icons.navigation_rounded,
                iconColor: const Color(0xFF42A5F5),
                tier: t,
                progressFrac: p.frac,
                progressLabel: p.label,
                thresholdLabel: _nextTierLabel(t, _navT),
              );
            }(),
          ],
        ),
        const SizedBox(height: 16),

        // ── Tier legend ─────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tier Thresholds (place badges)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TierChip(tier: BadgeTier.bronze,   label: '5+'),
                    _TierChip(tier: BadgeTier.silver,   label: '15+'),
                    _TierChip(tier: BadgeTier.gold,     label: '25+'),
                    _TierChip(tier: BadgeTier.platinum, label: '40+'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
      BuildContext context, IconData icon, String title, String subtitle) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  String _nextTierLabel(BadgeTier t, List<int> thresholds) {
    if (t == BadgeTier.platinum) return 'Max tier reached!';
    if (t == BadgeTier.gold) return 'Platinum at ${thresholds[3]}';
    if (t == BadgeTier.silver) return 'Gold at ${thresholds[2]}';
    if (t == BadgeTier.bronze) return 'Silver at ${thresholds[1]}';
    return 'Bronze at ${thresholds[0]}';
  }

  String _nextTierLabelD(BadgeTier t, List<double> thresholds, String unit) {
    if (t == BadgeTier.platinum) return 'Max tier reached!';
    if (t == BadgeTier.gold) return 'Platinum at ${thresholds[3].toStringAsFixed(0)} $unit';
    if (t == BadgeTier.silver) return 'Gold at ${thresholds[2].toStringAsFixed(0)} $unit';
    if (t == BadgeTier.bronze) return 'Silver at ${thresholds[1].toStringAsFixed(0)} $unit';
    return 'Bronze at ${thresholds[0].toStringAsFixed(0)} $unit';
  }
}

// ─────────────────────────────────────────────
// Stat summary card
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Badge card
// ─────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconColor;
  final BadgeTier tier;
  final double progressFrac;
  final String progressLabel;
  final String thresholdLabel;

  const _BadgeCard({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.tier,
    required this.progressFrac,
    required this.progressLabel,
    required this.thresholdLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tc = _tierColors[tier]!;
    final earned = tier != BadgeTier.locked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with tier ring
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: earned
                        ? iconColor.withValues(alpha: 0.12)
                        : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(color: tc, width: earned ? 3 : 1.5),
                  ),
                  child: Icon(icon,
                      size: 30,
                      color: earned ? iconColor : cs.outlineVariant),
                ),
                if (earned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: tc,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _tierLabels[tier]![0], // B / S / G / P
                      style: TextStyle(
                        color: tier == BadgeTier.gold ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tc.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _tierLabels[tier]!.toUpperCase(),
                style: TextStyle(
                    color: tier == BadgeTier.gold ? const Color(0xFFB8860B) : tc,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressFrac,
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(tc),
              ),
            ),
            const SizedBox(height: 4),
            Text(progressLabel,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(thresholdLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tier legend chip
// ─────────────────────────────────────────────
class _TierChip extends StatelessWidget {
  final BadgeTier tier;
  final String label;
  const _TierChip({required this.tier, required this.label});

  @override
  Widget build(BuildContext context) {
    final tc = _tierColors[tier]!;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tc.withValues(alpha: 0.15),
            border: Border.all(color: tc, width: 2),
          ),
          child: Center(
            child: Text(
              _tierLabels[tier]![0],
              style: TextStyle(
                  color: tier == BadgeTier.gold ? const Color(0xFFB8860B) : tc,
                  fontWeight: FontWeight.w900,
                  fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: tc,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

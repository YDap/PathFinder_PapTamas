import 'package:flutter/material.dart';
import 'places_api.dart';

// ─────────────────────────────────────────────
// Badge tier
// ─────────────────────────────────────────────
enum BadgeTier { locked, bronze, silver, gold, platinum }

const tierColors = <BadgeTier, Color>{
  BadgeTier.locked:   Color(0xFF9E9E9E),
  BadgeTier.bronze:   Color(0xFFCD7F32),
  BadgeTier.silver:   Color(0xFFB0B7C3),
  BadgeTier.gold:     Color(0xFFFFD700),
  BadgeTier.platinum: Color(0xFF00BCD4),
};

const tierLabels = <BadgeTier, String>{
  BadgeTier.locked:   'Locked',
  BadgeTier.bronze:   'Bronze',
  BadgeTier.silver:   'Silver',
  BadgeTier.gold:     'Gold',
  BadgeTier.platinum: 'Platinum',
};

// ─────────────────────────────────────────────
// Badge thresholds
// ─────────────────────────────────────────────
const placeThresholds   = [5, 15, 25, 40];
const postThresholds    = [5, 15, 25, 50];
const explorerThresholds = [2, 4, 5, 6];
const navThresholds     = [5, 15, 30, 60];
final  kmThresholds     = [10.0, 50.0, 150.0, 500.0];

// ─────────────────────────────────────────────
// Badge definitions
// ─────────────────────────────────────────────
class BadgeDef {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  const BadgeDef(this.key, this.name, this.icon, this.color);
}

const naturalCategories = ['peak', 'lake', 'cave', 'ruin', 'spring', 'viewpoint'];

const placeBadgeDefs = <BadgeDef>[
  BadgeDef('peak',      'Peak Climber',  Icons.landscape,          Color(0xFF7E57C2)),
  BadgeDef('lake',      'Lake Explorer', Icons.water_rounded,       Color(0xFF42A5F5)),
  BadgeDef('cave',      'Cave Diver',    Icons.terrain,             Color(0xFF8D6E63)),
  BadgeDef('ruin',      'Ruin Hunter',   Icons.account_balance,     Color(0xFFEF5350)),
  BadgeDef('spring',    'Spring Seeker', Icons.water_drop,          Color(0xFF26A69A)),
  BadgeDef('viewpoint', 'Vista Chaser',  Icons.visibility,          Color(0xFF5C6BC0)),
];

const achievBadgeDefs = <BadgeDef>[
  BadgeDef('km',       'Long Hauler',   Icons.route_rounded,        Color(0xFFFF7043)),
  BadgeDef('posts',    'Storyteller',   Icons.auto_stories_rounded,  Color(0xFF66BB6A)),
  BadgeDef('explorer', 'True Explorer', Icons.explore_rounded,       Color(0xFF26C6DA)),
  BadgeDef('nav',      'Road Warrior',  Icons.navigation_rounded,    Color(0xFF42A5F5)),
];

// ─────────────────────────────────────────────
// Tier computation
// ─────────────────────────────────────────────
BadgeTier badgeTier(int count, List<int> t) {
  if (count >= t[3]) return BadgeTier.platinum;
  if (count >= t[2]) return BadgeTier.gold;
  if (count >= t[1]) return BadgeTier.silver;
  if (count >= t[0]) return BadgeTier.bronze;
  return BadgeTier.locked;
}

BadgeTier badgeTierD(double v, List<double> t) {
  if (v >= t[3]) return BadgeTier.platinum;
  if (v >= t[2]) return BadgeTier.gold;
  if (v >= t[1]) return BadgeTier.silver;
  if (v >= t[0]) return BadgeTier.bronze;
  return BadgeTier.locked;
}

({double frac, String label}) badgeProgress(int count, List<int> t) {
  if (count >= t[3]) return (frac: 1.0, label: '$count — MAX');
  int prev = 0, next = t[0];
  if (count >= t[2]) { prev = t[2]; next = t[3]; }
  else if (count >= t[1]) { prev = t[1]; next = t[2]; }
  else if (count >= t[0]) { prev = t[0]; next = t[1]; }
  return (frac: ((count - prev) / (next - prev)).clamp(0.0, 1.0), label: '$count / $next');
}

({double frac, String label}) badgeProgressD(double v, List<double> t) {
  if (v >= t[3]) return (frac: 1.0, label: '${v.toStringAsFixed(1)} km — MAX');
  double prev = 0, next = t[0];
  if (v >= t[2]) { prev = t[2]; next = t[3]; }
  else if (v >= t[1]) { prev = t[1]; next = t[2]; }
  else if (v >= t[0]) { prev = t[0]; next = t[1]; }
  return (frac: ((v - prev) / (next - prev)).clamp(0.0, 1.0), label: '${v.toStringAsFixed(1)} / ${next.toStringAsFixed(0)} km');
}

String nextTierLabel(BadgeTier t, List<int> thresholds) {
  if (t == BadgeTier.platinum) return 'Max tier reached!';
  if (t == BadgeTier.gold)     return 'Platinum at ${thresholds[3]}';
  if (t == BadgeTier.silver)   return 'Gold at ${thresholds[2]}';
  if (t == BadgeTier.bronze)   return 'Silver at ${thresholds[1]}';
  return 'Bronze at ${thresholds[0]}';
}

String nextTierLabelD(BadgeTier t, List<double> thresholds, String unit) {
  if (t == BadgeTier.platinum) return 'Max tier reached!';
  if (t == BadgeTier.gold)     return 'Platinum at ${thresholds[3].toStringAsFixed(0)} $unit';
  if (t == BadgeTier.silver)   return 'Gold at ${thresholds[2].toStringAsFixed(0)} $unit';
  if (t == BadgeTier.bronze)   return 'Silver at ${thresholds[1].toStringAsFixed(0)} $unit';
  return 'Bronze at ${thresholds[0].toStringAsFixed(0)} $unit';
}

// ─────────────────────────────────────────────
// XP & Level system
// ─────────────────────────────────────────────

// XP bonuses per tier (cumulative on unlock)
const _tierBonus = <BadgeTier, int>{
  BadgeTier.bronze:   50,
  BadgeTier.silver:   150,
  BadgeTier.gold:     300,
  BadgeTier.platinum: 600,
};

int _tierXp(BadgeTier tier) {
  if (tier == BadgeTier.locked) return 0;
  int xp = 0;
  for (final t in BadgeTier.values) {
    if (t == BadgeTier.locked) continue;
    if (t.index <= tier.index) xp += _tierBonus[t]!;
  }
  return xp;
}

/// Total XP earned from all stats and badge unlocks.
int computeXp(UserStats stats) {
  int xp = 0;

  // Activity XP
  xp += stats.totalVisits * 10;
  xp += (stats.totalKm * 2).round();
  xp += stats.postsCount * 25;

  // Place badge bonuses
  for (final def in placeBadgeDefs) {
    final count = stats.visitsByCategory[def.key] ?? 0;
    xp += _tierXp(badgeTier(count, placeThresholds));
  }

  // Achievement badge bonuses
  xp += _tierXp(badgeTierD(stats.totalKm, kmThresholds));
  xp += _tierXp(badgeTier(stats.postsCount, postThresholds));
  final distinctNat = naturalCategories.where((c) => (stats.visitsByCategory[c] ?? 0) > 0).length;
  xp += _tierXp(badgeTier(distinctNat, explorerThresholds));
  xp += _tierXp(badgeTier(stats.totalNavigations, navThresholds));

  return xp;
}

/// Total XP needed to START level [level] (level 1 starts at 0).
int xpForLevel(int level) {
  if (level <= 1) return 0;
  // XP per level-up from level k: 200 + 50*(k-1)
  // Cumulative: 200*(L-1) + 50*(L-1)*(L-2)/2
  final n = level - 1;
  return 200 * n + 25 * n * (n - 1);
}

/// Current level for a given total XP.
int levelFromXp(int xp) {
  int level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// XP needed to advance from the start of [level] to the next.
int xpPerLevel(int level) => 200 + 50 * (level - 1);

const _levelTitles = <String>[
  'Wanderer',       // 1
  'Trailhead',      // 2
  'Scout',          // 3
  'Pathfinder',     // 4
  'Hiker',          // 5
  'Trailblazer',    // 6
  'Mountaineer',    // 7
  'Explorer',       // 8
  'Ranger',         // 9
  'Summit Seeker',  // 10
  'Peak Hunter',    // 11
  'Navigator',      // 12
  'Adventurer',     // 13
  'Traverse Master',// 14
  'Trail Veteran',  // 15
  'Wilderness Guide', // 16
  'Mountain Legend',  // 17
  'Grand Explorer',   // 18
  'Elite Pathfinder', // 19
];

String levelTitle(int level) {
  if (level <= 0) return 'Wanderer';
  if (level <= _levelTitles.length) return _levelTitles[level - 1];
  return 'Grand Pathfinder'; // 20+
}

// ─────────────────────────────────────────────
// Recently unlocked detection
// ─────────────────────────────────────────────

class UnlockedBadge {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final BadgeTier tier;
  const UnlockedBadge({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.tier,
  });
}

/// Computes the current set of earned badges from [stats] as a map of
/// badgeKey → tier name.  Used to detect newly unlocked badges.
Map<String, String> currentBadgeState(UserStats stats) {
  final map = <String, String>{};
  final distinctNat = naturalCategories.where((c) => (stats.visitsByCategory[c] ?? 0) > 0).length;

  for (final def in placeBadgeDefs) {
    final count = stats.visitsByCategory[def.key] ?? 0;
    map[def.key] = badgeTier(count, placeThresholds).name;
  }
  map['km']       = badgeTierD(stats.totalKm, kmThresholds).name;
  map['posts']    = badgeTier(stats.postsCount, postThresholds).name;
  map['explorer'] = badgeTier(distinctNat, explorerThresholds).name;
  map['nav']      = badgeTier(stats.totalNavigations, navThresholds).name;
  return map;
}

/// Given a badge key and tier name, builds an [UnlockedBadge] for display.
UnlockedBadge? unlockedBadgeFor(String key, String tierName) {
  final tier = BadgeTier.values.firstWhere(
    (t) => t.name == tierName,
    orElse: () => BadgeTier.locked,
  );
  if (tier == BadgeTier.locked) return null;

  BadgeDef? def = placeBadgeDefs.cast<BadgeDef?>().firstWhere(
    (d) => d?.key == key,
    orElse: () => null,
  );
  def ??= achievBadgeDefs.cast<BadgeDef?>().firstWhere(
    (d) => d?.key == key,
    orElse: () => null,
  );
  if (def == null) return null;
  return UnlockedBadge(key: key, name: def.name, icon: def.icon, color: def.color, tier: tier);
}

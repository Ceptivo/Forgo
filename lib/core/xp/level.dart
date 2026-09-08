import 'dart:math';

/// Cumulative XP required to reach [level] (from 0). Matches the backend
/// formula exactly (see supabase/migrations/0021_xp_level_system.sql) —
/// level display is computed purely client-side from profiles.xp, no RPC
/// round trip needed.
int xpForLevel(int level) => 6 * (level - 1) * level;

/// The highest level reachable with [xp] total XP.
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  // Closed-form inverse of 6L^2 - 6L - xp <= 0, then corrected for
  // floating-point rounding at the boundary.
  var level = ((6 + sqrt(36 + 24 * xp)) / 12).floor();
  if (level < 1) level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  while (level > 1 && xpForLevel(level) > xp) {
    level--;
  }
  return level;
}

/// A user's level plus how far into it they are, for a level+progress-bar
/// display.
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get fraction =>
      xpForNextLevel == 0 ? 1.0 : (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);
}

LevelProgress levelProgressForXp(int xp) {
  final level = levelForXp(xp);
  final currentLevelXp = xpForLevel(level);
  final nextLevelXp = xpForLevel(level + 1);
  return LevelProgress(
    level: level,
    xpIntoLevel: xp - currentLevelXp,
    xpForNextLevel: nextLevelXp - currentLevelXp,
  );
}

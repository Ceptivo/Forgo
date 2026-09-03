/// A weekly-streak milestone. Earned permanently once
/// [StreakSummary.longestWeeklyStreak] reaches [weeks] — badges don't
/// disappear if the streak later breaks, since they mark something the
/// user already accomplished.
class StreakBadge {
  const StreakBadge({required this.weeks, required this.label});

  final int weeks;
  final String label;
}

/// Same tiers Strava's own streak rewards use.
const streakBadgeTiers = [
  StreakBadge(weeks: 12, label: '12 week streak'),
  StreakBadge(weeks: 26, label: '26 week streak'),
  StreakBadge(weeks: 52, label: '52 week streak'),
];

List<StreakBadge> earnedStreakBadges(int longestWeeklyStreak) {
  return streakBadgeTiers.where((b) => longestWeeklyStreak >= b.weeks).toList();
}

/// The next tier not yet earned, or null if all are earned.
StreakBadge? nextStreakBadge(int longestWeeklyStreak) {
  for (final badge in streakBadgeTiers) {
    if (longestWeeklyStreak < badge.weeks) return badge;
  }
  return null;
}

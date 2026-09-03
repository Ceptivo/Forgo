import '../../goals/domain/goal.dart';

/// One day in the home screen's weekly streak row — [activity] is null
/// for a day with no logged check-in.
class DayActivity {
  const DayActivity({required this.date, required this.activity});

  factory DayActivity.fromMap(Map<String, dynamic> map) {
    return DayActivity(
      date: DateTime.parse(map['date'] as String),
      activity: distanceActivityFromString(map['activity'] as String?),
    );
  }

  final DateTime date;
  final DistanceActivity? activity;
}

/// Everything the home screen, heatmap, and profile badges need about a
/// user's activity-check-in streaks — see get_streak_summary in
/// 0011_streaks.sql.
class StreakSummary {
  const StreakSummary({
    required this.currentDailyStreak,
    required this.currentWeeklyStreak,
    required this.longestWeeklyStreak,
    required this.last7Days,
  });

  factory StreakSummary.fromMap(Map<String, dynamic> map) {
    return StreakSummary(
      currentDailyStreak: (map['current_daily_streak'] as num).toInt(),
      currentWeeklyStreak: (map['current_weekly_streak'] as num).toInt(),
      longestWeeklyStreak: (map['longest_weekly_streak'] as num).toInt(),
      last7Days: (map['last_7_days'] as List)
          .map((e) => DayActivity.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int currentDailyStreak;
  final int currentWeeklyStreak;
  final int longestWeeklyStreak;
  final List<DayActivity> last7Days;
}

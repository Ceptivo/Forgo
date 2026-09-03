import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../goals/domain/goal.dart';
import '../../../goals/presentation/widgets/goal_card.dart';
import '../../application/streak_providers.dart';
import '../../domain/activity_check_in.dart';
import '../../domain/streak_badge.dart';

/// Tapped from the dashboard's streak widget — current streaks, a
/// week-by-week check-in heatmap, and progress toward the 12/26/52-week
/// streak badges (see streak_badge.dart). Every day on here comes from
/// completing a goal (see log_goal_progress / complete_weight_loss_goal
/// in 0012_goal_driven_streaks.sql) — there's no free-standing "log an
/// activity" action any more, so this screen is read-only.
class StreakHeatmapScreen extends ConsumerWidget {
  const StreakHeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Streak')),
      body: userId == null
          ? const Center(child: Text('Not signed in.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(streakSummaryProvider(userId));
                ref.invalidate(checkInHistoryProvider(userId));
              },
              child: ResponsivePage(
                child: _StreakBody(userId: userId),
              ),
            ),
    );
  }
}

class _StreakBody extends ConsumerWidget {
  const _StreakBody({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(streakSummaryProvider(userId));

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RetryableError(
        message: 'Could not load your streak.',
        onRetry: () => ref.invalidate(streakSummaryProvider(userId)),
      ),
      data: (summary) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Complete a goal to add today to your streak — this is '
              'built from your goals, not logged separately.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StreakStat(
                    icon: Icons.local_fire_department_rounded,
                    value: '${summary.currentDailyStreak}',
                    label: summary.currentDailyStreak == 1 ? 'day streak' : 'days streak',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakStat(
                    icon: Icons.calendar_month_rounded,
                    value: '${summary.currentWeeklyStreak}',
                    label: summary.currentWeeklyStreak == 1 ? 'week streak' : 'weeks streak',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Badges', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Reach a weekly streak milestone to earn a badge — it stays '
              'on your profile even if the streak later breaks.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final badge in streakBadgeTiers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BadgeProgressCard(
                  badge: badge,
                  longestWeeklyStreak: summary.longestWeeklyStreak,
                  currentWeeklyStreak: summary.currentWeeklyStreak,
                ),
              ),
            const SizedBox(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _HeatmapSection(userId: userId),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(height: 10),
          Text(value, style: textTheme.headlineSmall),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BadgeProgressCard extends StatelessWidget {
  const _BadgeProgressCard({
    required this.badge,
    required this.longestWeeklyStreak,
    required this.currentWeeklyStreak,
  });

  final StreakBadge badge;
  final int longestWeeklyStreak;
  final int currentWeeklyStreak;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final earned = longestWeeklyStreak >= badge.weeks;
    final progress = earned
        ? 1.0
        : (currentWeeklyStreak / badge.weeks).clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: earned ? AppColors.accentDim : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned ? AppColors.accent : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: earned ? AppColors.ink : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.emoji_events_rounded,
              color: earned ? AppColors.accent : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(badge.label, style: textTheme.titleMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accentDeep),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  earned
                      ? 'Earned'
                      : '$currentWeeklyStreak / ${badge.weeks} weeks',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapSection extends ConsumerWidget {
  const _HeatmapSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(checkInHistoryProvider(userId));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Text(
        'Could not load history.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      data: (checkIns) => _Heatmap(checkIns: checkIns),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.checkIns});

  final List<ActivityCheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    final byDate = <DateTime, DistanceActivity>{};
    for (final checkIn in checkIns) {
      final d = DateTime(
        checkIn.loggedDate.year,
        checkIn.loggedDate.month,
        checkIn.loggedDate.day,
      );
      byDate[d] = checkIn.activity;
    }

    final today = DateTime.now();
    final startOfThisWeek = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));

    // 16 weeks, oldest first.
    final weekStarts = [
      for (var i = 15; i >= 0; i--) startOfThisWeek.subtract(Duration(days: 7 * i)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WeekdayHeader(),
        const SizedBox(height: 6),
        for (final weekStart in weekStarts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _DayCell(
                      activity: byDate[weekStart.add(Duration(days: i))],
                      isFuture: weekStart.add(Duration(days: i)).isAfter(today),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Text(labels[i], textAlign: TextAlign.center, style: style),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.activity, required this.isFuture});

  final DistanceActivity? activity;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: isFuture
              ? Colors.transparent
              : activity != null
              ? AppColors.accentDim
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: activity == null
            ? null
            : Icon(goalActivityIcons[activity], size: 14, color: AppColors.accentDeep),
      ),
    );
  }
}

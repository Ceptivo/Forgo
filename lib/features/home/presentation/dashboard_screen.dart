import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_grid.dart';
import '../../../core/widgets/retryable_error.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/screens/new_goal_screen.dart';
import '../../goals/presentation/widgets/goal_card.dart';
import '../../profile/application/profile_providers.dart';
import '../../social/application/social_providers.dart';
import '../../streaks/application/streak_providers.dart';
import '../../streaks/domain/streak_summary.dart';
import '../../streaks/presentation/screens/streak_heatmap_screen.dart';
import 'about_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final textTheme = Theme.of(context).textTheme;
    final profile = profileAsync.value;
    final firstName = profile?.fullName.split(' ').first;
    final activeGoalsCount =
        goalsAsync.value?.where((g) => g.status == GoalStatus.active).length ??
        0;
    final hasError = profileAsync.hasError || goalsAsync.hasError;

    void openNewGoal() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewGoalScreen()));

    void retry() {
      ref.invalidate(currentProfileProvider);
      ref.invalidate(goalsProvider);
    }

    return Scaffold(
      // No app bar — that pushed the greeting down from where it used to
      // sit. The info icon instead sits in the same row as the greeting
      // text, so it's genuinely in line with it rather than eyeballed
      // via a fixed offset.
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    firstName == null ? 'Welcome to Forgo' : 'Hey, $firstName',
                    style: textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'About Forgo',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Stake money, prove it with a photo, keep it.',
              style: textTheme.bodyMedium,
            ),
            if (hasError)
              RetryableError(
                message: 'Could not load your data.',
                onRetry: retry,
              ),
            const SizedBox(height: 24),
            _ActiveGoalsCard(
              activeCount: activeGoalsCount,
              onTap: activeGoalsCount == 0
                  ? openNewGoal
                  : () => context.go('/goals'),
            ),
            const SizedBox(height: 12),
            BentoGrid(
              items: [
                BentoGridItem(
                  size: BentoSize.half,
                  child: _StatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Wallet',
                    value:
                        'R${(profile?.walletBalanceRand ?? 0).toStringAsFixed(0)}',
                    onTap: () => context.go('/wallet'),
                  ),
                ),
                BentoGridItem(
                  size: BentoSize.half,
                  child: profile == null
                      ? const _StatCard(
                          icon: Icons.volunteer_activism_rounded,
                          label: 'Given to charity',
                          value: '—',
                        )
                      : _CharityStatCard(userId: profile.id),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (profile != null) _StreakSection(userId: profile.id),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Your goals', style: textTheme.titleMedium),
                const Spacer(),
                if (activeGoalsCount > 0)
                  TextButton(
                    onPressed: () => context.go('/goals'),
                    child: const Text('See all'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _GoalListPreview(
              goals: goalsAsync.value ?? const [],
              loading: goalsAsync.isLoading,
              onNewGoal: openNewGoal,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentDeep, size: 22),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CharityStatCard extends ConsumerWidget {
  const _CharityStatCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final given = statsAsync.value?.charityGivenRand;
    return _StatCard(
      icon: Icons.volunteer_activism_rounded,
      label: 'Given to charity',
      value: given == null ? '—' : 'R${given.toStringAsFixed(0)}',
    );
  }
}

class _ActiveGoalsCard extends StatelessWidget {
  const _ActiveGoalsCard({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasGoals = activeCount > 0;

    return BentoCard(
      onTap: onTap,
      gradient: AppColors.accentGradient,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillBadge(
                  label: hasGoals
                      ? '$activeCount ACTIVE ${activeCount == 1 ? 'GOAL' : 'GOALS'}'
                      : 'NO ACTIVE GOALS',
                  color: AppColors.ink,
                  filled: true,
                ),
                const SizedBox(height: 12),
                Text(
                  hasGoals
                      ? 'Keep your streak alive'
                      : 'Start your first commitment',
                  style: textTheme.titleLarge?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  hasGoals
                      ? 'Tap to see your active goals and log progress.'
                      : 'Pick a goal, set your stake, and put your money '
                            'where your goals are.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_circle_right_rounded,
            color: AppColors.ink,
            size: 32,
          ),
        ],
      ),
    );
  }
}

/// Weekly streak row — a day-icon per weekday (M..S), showing the
/// activity logged that day, same idea as Strava's streak row but in
/// Forgo's own light/black/mint language. Tapping it opens the full
/// heatmap + badge screen.
class _StreakSection extends ConsumerWidget {
  const _StreakSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(streakSummaryProvider(userId));
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StreakHeatmapScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: summaryAsync.when(
            loading: () => const SizedBox(
              height: 76,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) =>
                Text('Could not load your streak.', style: textTheme.bodySmall),
            data: (summary) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        summary.currentDailyStreak == 1
                            ? '1 day streak'
                            : '${summary.currentDailyStreak} day streak',
                        style: textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final day in summary.last7Days) ...[
                        Expanded(child: _StreakDay(day: day)),
                        if (day != summary.last7Days.last)
                          const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StreakDay extends StatelessWidget {
  const _StreakDay({required this.day});

  final DayActivity day;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(day.date, DateTime.now());
    const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final letter = weekdayLetters[day.date.weekday - 1];

    return Column(
      children: [
        Text(letter, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: day.activity != null
                ? AppColors.accentDim
                : AppColors.surfaceMuted,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: AppColors.ink, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: day.activity == null
              ? null
              : Icon(
                  goalActivityIcons[day.activity],
                  size: 16,
                  color: AppColors.accentDeep,
                ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _GoalListPreview extends StatelessWidget {
  const _GoalListPreview({
    required this.goals,
    required this.loading,
    required this.onNewGoal,
  });

  final List<Goal> goals;
  final bool loading;
  final VoidCallback onNewGoal;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final active = goals.where((g) => g.status == GoalStatus.active).toList();

    if (active.isEmpty) {
      return BentoCard(
        onTap: onNewGoal,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.accentDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New goal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Distance, time, or weight-loss — choose your stake',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      );
    }

    final preview = active.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GoalCard(goal: goal),
          ),
      ],
    );
  }
}

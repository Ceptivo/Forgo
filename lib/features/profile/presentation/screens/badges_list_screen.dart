import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../social/application/social_providers.dart';
import '../../../streaks/application/streak_providers.dart';
import '../../../streaks/domain/streak_badge.dart';

/// Every badge that exists in Forgo, not just the ones a user has
/// earned — locked ones show greyed out so there's something to work
/// toward, same idea as the streak heatmap's badge-progress cards.
class BadgesListScreen extends ConsumerWidget {
  const BadgesListScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakSummaryProvider(userId));
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final textTheme = Theme.of(context).textTheme;

    final loading = streakAsync.isLoading || statsAsync.isLoading;
    final hasFirstGoal = (statsAsync.value?.completedGoalsCount ?? 0) >= 1;
    final longestWeeklyStreak = streakAsync.value?.longestWeeklyStreak ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsivePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BadgeRow(
                    icon: Icons.military_tech_rounded,
                    title: '1st Goal Accomplished',
                    description: 'Complete your very first goal.',
                    earned: hasFirstGoal,
                  ),
                  const SizedBox(height: 10),
                  for (final tier in streakBadgeTiers) ...[
                    _BadgeRow(
                      icon: Icons.emoji_events_rounded,
                      title: tier.label,
                      description: 'Reach a ${tier.weeks}-week streak.',
                      earned: longestWeeklyStreak >= tier.weeks,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Badges are permanent once earned — they stay on your '
                    'profile even if a streak later breaks.',
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.earned,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: earned ? AppColors.ink : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: earned ? AppColors.accent : AppColors.textMuted,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (earned)
            const Icon(Icons.check_circle_rounded, color: AppColors.accentDeep)
          else
            const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

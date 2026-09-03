import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/presentation/screens/follow_list_screen.dart';
import '../../../streaks/application/streak_providers.dart';
import '../../../streaks/domain/streak_badge.dart';

/// The stat/info cards shared by a user's own profile and the profile
/// they show to everyone else — kept as one shared set of widgets so the
/// two screens can't drift apart and end up looking different.
class CompletedGoalsCard extends ConsumerWidget {
  const CompletedGoalsCard({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final completed = statsAsync.value?.completedGoalsCount;

    return BentoCard(
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          Text(completed?.toString() ?? '—', style: textTheme.titleLarge),
          const SizedBox(width: 8),
          Text('Goals completed', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class CharityGivenCard extends ConsumerWidget {
  const CharityGivenCard({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final givenRand = statsAsync.value?.charityGivenRand;

    return BentoCard(
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          Text(
            givenRand == null ? '—' : 'R${givenRand.toStringAsFixed(2)}',
            style: textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          Text('Given to charity', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Every badge a user has earned — the streak milestones (12/26/52
/// weeks) plus "1st Goal Accomplished" the moment their completed-goals
/// count reaches one. All still just a trophy icon + label for now, so
/// this stays a single flat list rather than modelling badge "kinds".
class BadgesSection extends ConsumerWidget {
  const BadgesSection({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakSummaryProvider(userId));
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final textTheme = Theme.of(context).textTheme;

    if (streakAsync.isLoading || statsAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final labels = <String>[
      if ((statsAsync.value?.completedGoalsCount ?? 0) >= 1)
        '1st Goal Accomplished',
      for (final badge in earnedStreakBadges(
        streakAsync.value?.longestWeeklyStreak ?? 0,
      ))
        badge.label,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Badges', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          if (labels.isEmpty)
            Text(
              'Complete a goal or keep a weekly streak going to earn your '
              'first badge.',
              style: textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final label in labels) _BadgeChip(label: label)],
            ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.accent,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Follower/following counts — tapping either opens the full list.
class FollowStatsRow extends ConsumerWidget {
  const FollowStatsRow({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final stats = statsAsync.value;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FollowStat(
              label: 'Followers',
              value: stats?.followerCount,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                    userId: userId,
                    mode: FollowListMode.followers,
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.surfaceBorder),
          Expanded(
            child: _FollowStat(
              label: 'Following',
              value: stats?.followingCount,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                    userId: userId,
                    mode: FollowListMode.following,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowStat extends StatelessWidget {
  const _FollowStat({required this.label, required this.value, required this.onTap});

  final String label;
  final int? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(value?.toString() ?? '—', style: textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

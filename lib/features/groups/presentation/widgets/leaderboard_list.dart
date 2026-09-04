import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/goal_group_providers.dart';
import '../../domain/goal_group_leaderboard_entry.dart';

/// A group's leaderboard — ranked by completions, then fewest fails.
/// Shared between a normal group's Leaderboard tab and the community
/// screen (which has no chat, just goals + this).
class LeaderboardList extends ConsumerWidget {
  const LeaderboardList({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(goalGroupLeaderboardProvider(groupId));
    final textTheme = Theme.of(context).textTheme;

    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: RetryableError(
          message: 'Could not load the leaderboard.',
          onRetry: () => ref.invalidate(goalGroupLeaderboardProvider(groupId)),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No goals resolved yet — the leaderboard fills in once '
                'someone reports an outcome.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _LeaderboardRow(rank: index + 1, entry: entries[index]),
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.entry});

  final int rank;
  final GoalGroupLeaderboardEntry entry;

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
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: textTheme.titleMedium?.copyWith(
                color: rank == 1 ? AppColors.accentDeep : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fullName, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${entry.completions} hit · ${entry.fails} missed',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+R${entry.wonRand.toStringAsFixed(0)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '-R${entry.lostRand.toStringAsFixed(0)}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

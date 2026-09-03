import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../application/goal_providers.dart';
import '../../domain/goal.dart';
import 'new_goal_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewGoalScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: GlowBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(goalsProvider);
            await ref.read(goalsProvider.future);
          },
          child: ResponsivePage(
            child: goalsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Could not load goals.',
                  style: textTheme.bodyMedium,
                ),
              ),
              data: (goals) {
                if (goals.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        const PillBadge(label: 'NO GOALS YET'),
                        const SizedBox(height: 12),
                        Text(
                          'Start your first commitment',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "New goal" to stake money on a goal.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final goal in goals) _GoalCard(goal: goal),
                    const SizedBox(height: 72), // clear of the FAB
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const _distanceActivityIcons = {
  DistanceActivity.run: Icons.directions_run_rounded,
  DistanceActivity.walk: Icons.directions_walk_rounded,
  DistanceActivity.cycle: Icons.directions_bike_rounded,
  DistanceActivity.swim: Icons.pool_rounded,
};

IconData _goalIcon(Goal goal) {
  if (goal.type == GoalType.weightLoss) return Icons.monitor_weight_outlined;
  return _distanceActivityIcons[goal.distanceActivity] ??
      Icons.directions_run_rounded;
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (statusColor, statusLabel) = switch (goal.status) {
      GoalStatus.active => (AppColors.accentBright, 'Active'),
      GoalStatus.completed => (AppColors.success, 'Completed'),
      GoalStatus.failed => (AppColors.danger, 'Failed'),
      GoalStatus.cancelled => (AppColors.textMuted, 'Cancelled'),
    };

    final detail = goal.deadline != null
        ? 'By ${DateFormat.yMMMd().format(goal.deadline!)}'
        : 'Weekly commitment';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_goalIcon(goal), color: AppColors.accentBright),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(goal.title, style: textTheme.titleMedium),
                ),
                PillBadge(label: statusLabel.toUpperCase(), color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$detail · R${goal.stakeRand.toStringAsFixed(2)} staked',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

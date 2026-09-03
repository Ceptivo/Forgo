import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../domain/goal.dart';
import '../screens/goal_detail_screen.dart';

const goalActivityIcons = {
  DistanceActivity.run: Icons.directions_run_rounded,
  DistanceActivity.walk: Icons.directions_walk_rounded,
  DistanceActivity.cycle: Icons.directions_bike_rounded,
  DistanceActivity.swim: Icons.pool_rounded,
};

IconData goalIcon(Goal goal) {
  if (goal.type == GoalType.weightLoss) return Icons.monitor_weight_outlined;
  return goalActivityIcons[goal.distanceActivity] ?? Icons.directions_run_rounded;
}

/// A single goal's card — icon, title, status pill, and a detail line
/// (deadline/cadence + stake). Shared between the full Goals list and the
/// dashboard's "Your goals" preview. Tapping it opens the goal's own page
/// (GoalDetailScreen) rather than expanding inline, which stops working
/// once there are more than a couple of goals in the list.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (statusColor, statusLabel) = switch (goal.status) {
      GoalStatus.active => (AppColors.accentDeep, 'Active'),
      GoalStatus.completed => (AppColors.success, 'Completed'),
      GoalStatus.failed => (AppColors.danger, 'Failed'),
      GoalStatus.cancelled => (AppColors.textMuted, 'Cancelled'),
    };

    final detail = goal.deadline != null
        ? 'By ${DateFormat.yMMMd().format(goal.deadline!)}'
        : 'Weekly commitment';

    return BentoCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GoalDetailScreen(goal: goal)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(goalIcon(goal), color: AppColors.accentDeep),
              const SizedBox(width: 10),
              Expanded(child: Text(goal.title, style: textTheme.titleMedium)),
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
    );
  }
}

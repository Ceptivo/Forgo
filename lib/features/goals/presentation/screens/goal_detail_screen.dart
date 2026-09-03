import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../social/application/social_providers.dart';
import '../../../streaks/application/streak_providers.dart';
import '../../../wallet/application/wallet_providers.dart';
import '../../application/goal_providers.dart';
import '../../data/goal_repository.dart';
import '../../domain/goal.dart';
import '../widgets/goal_card.dart';

/// A single goal's own page — full details, plus (while active) the
/// self-reported action that moves it forward: logging today's progress
/// for a distance/time goal, or marking a weight-loss goal reached.
/// Reached by tapping a goal card, rather than an inline expansion in
/// the list, since that doesn't scale once there are more than a
/// handful of goals.
class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goal});

  final Goal goal;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  late Goal _goal = widget.goal;
  bool _busy = false;

  Future<void> _logProgress() async {
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(goalRepositoryProvider)
          .logGoalProgress(_goal.id);
      ref.invalidate(goalsProvider);
      ref.invalidate(streakSummaryProvider);
      ref.invalidate(checkInHistoryProvider);
      ref.invalidate(walletTransactionsProvider);
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null) ref.invalidate(publicProfileStatsProvider(userId));
      if (!mounted) return;
      setState(() => _goal = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.status == GoalStatus.completed
                ? 'Goal completed — your stake is back in your wallet.'
                : "Logged for today — keep the streak going.",
          ),
        ),
      );
    } on GoalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markWeightLossReached() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark goal as reached?'),
        content: const Text(
          "This confirms you've hit your target weight. Your stake will "
          'be refunded to your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(goalRepositoryProvider)
          .completeWeightLossGoal(_goal.id);
      ref.invalidate(goalsProvider);
      ref.invalidate(walletTransactionsProvider);
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null) ref.invalidate(publicProfileStatsProvider(userId));
      if (!mounted) return;
      setState(() => _goal = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal completed — your stake is back in your wallet.'),
        ),
      );
    } on GoalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final goal = _goal;
    final (statusColor, statusLabel) = switch (goal.status) {
      GoalStatus.active => (AppColors.accentDeep, 'Active'),
      GoalStatus.completed => (AppColors.success, 'Completed'),
      GoalStatus.failed => (AppColors.danger, 'Failed'),
      GoalStatus.cancelled => (AppColors.textMuted, 'Cancelled'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Goal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(goalIcon(goal), color: AppColors.accentDeep, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(goal.title, style: textTheme.titleLarge),
                      ),
                      PillBadge(
                        label: statusLabel.toUpperCase(),
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label: 'Staked',
                    value: 'R${goal.stakeRand.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Cadence',
                    value: goal.deadline != null
                        ? 'One-off, by ${DateFormat.yMMMd().format(goal.deadline!)}'
                        : 'Weekly commitment',
                  ),
                  if (goal.distanceActivity != null)
                    _DetailRow(
                      label: 'Activity',
                      value: distanceActivityLabel(goal.distanceActivity!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (goal.status == GoalStatus.active) ...[
              if (goal.type == GoalType.weightLoss)
                _ActionCard(
                  title: 'Reached your target?',
                  body:
                      'No automated tracking yet — tell us yourself once '
                      "you've hit it.",
                  buttonLabel: 'Mark as reached',
                  busy: _busy,
                  onPressed: _markWeightLossReached,
                )
              else
                _ActionCard(
                  title: goal.distanceCadence == DistanceCadence.once
                      ? "Done it?"
                      : "Log today's progress",
                  body: goal.distanceCadence == DistanceCadence.once
                      ? 'Self-reported, same as everywhere else in Forgo — '
                            'this completes the goal and refunds your stake.'
                      : 'Adds today to your streak. This goal stays active '
                            "since it's a recurring, weekly commitment.",
                  buttonLabel: goal.distanceCadence == DistanceCadence.once
                      ? 'Mark as done'
                      : "Log today's ${distanceActivityLabel(goal.distanceActivity!).toLowerCase()}",
                  busy: _busy,
                  onPressed: _logProgress,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Text(label, style: textTheme.bodySmall),
          const Spacer(),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: textTheme.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

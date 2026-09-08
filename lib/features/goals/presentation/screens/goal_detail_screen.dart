import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/presentation/screens/strava_screen.dart';
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

  void _onProgressLogged(Goal updated) {
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
                _StravaUploadCard(goal: goal, onLogged: _onProgressLogged),
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

/// The self-report action for a distance/time goal — same trust level as
/// everywhere else in Forgo (nothing here reads or checks the
/// screenshot), but now backed by an attached Strava screenshot and
/// username rather than just a tap, so there's a real record behind it.
class _StravaUploadCard extends ConsumerStatefulWidget {
  const _StravaUploadCard({required this.goal, required this.onLogged});

  final Goal goal;
  final ValueChanged<Goal> onLogged;

  @override
  ConsumerState<_StravaUploadCard> createState() => _StravaUploadCardState();
}

class _StravaUploadCardState extends ConsumerState<_StravaUploadCard> {
  XFile? _picked;
  bool _busy = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _picked = picked);
  }

  Future<void> _submit(String stravaUsername) async {
    final picked = _picked;
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final userId = ref.read(currentUserProvider)!.id;
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final proofUrl = await ref
          .read(goalRepositoryProvider)
          .uploadGoalProof(
            userId: userId,
            goalId: widget.goal.id,
            bytes: bytes,
            fileExtension: extension,
          );
      final updated = await ref
          .read(goalRepositoryProvider)
          .logGoalProgress(
            goalId: widget.goal.id,
            proofImageUrl: proofUrl,
            stravaUsername: stravaUsername,
          );
      if (!mounted) return;
      setState(() => _picked = null);
      widget.onLogged(updated);
    } on GoalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final textTheme = Theme.of(context).textTheme;
    final stravaUsername = ref.watch(currentProfileProvider).value?.stravaUsername;
    final missingUsername = stravaUsername == null || stravaUsername.isEmpty;

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
          Row(
            children: [
              Image.asset(
                'assets/images/strava.png',
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.directions_run_rounded,
                  color: AppColors.accentDeep,
                ),
              ),
              const SizedBox(width: 10),
              Text('Upload Strava', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (missingUsername) ...[
            Text(
              'Strava username missing',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your Strava username in Settings before you can upload '
              'proof for this goal.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StravaScreen()),
              ),
              child: const Text('Add Strava username'),
            ),
          ] else ...[
            Text(
              'Upload a screenshot of this activity from Strava — the '
              'activity type, distance, and time should be visible.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_picked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _picked!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_picked == null ? 'Choose screenshot' : 'Change screenshot'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_picked == null || _busy)
                    ? null
                    : () => _submit(stravaUsername),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        goal.distanceCadence == DistanceCadence.once
                            ? 'Mark as done'
                            : "Log today's ${distanceActivityLabel(goal.distanceActivity!).toLowerCase()}",
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

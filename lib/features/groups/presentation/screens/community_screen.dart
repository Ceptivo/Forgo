import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group_round.dart';
import '../../domain/goal_group_stake.dart';
import '../widgets/leaderboard_list.dart';

/// Forgo's own community — every user is automatically a member (see
/// 0015_community.sql). No chat here, just goals set by the developer
/// that anyone can join, and a leaderboard of the whole community.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Forgo'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Goals'), Tab(text: 'Leaderboard')],
          ),
        ),
        body: const TabBarView(
          children: [
            _CommunityGoalsTab(),
            LeaderboardList(groupId: kCommunityGroupId),
          ],
        ),
      ),
    );
  }
}

class _CommunityGoalsTab extends ConsumerWidget {
  const _CommunityGoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(
      goalGroupActiveRoundsProvider(kCommunityGroupId),
    );
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(goalGroupRoundsProvider(kCommunityGroupId));
        await ref.read(goalGroupRoundsProvider(kCommunityGroupId).future);
      },
      child: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load community goals.',
            onRetry: () =>
                ref.invalidate(goalGroupRoundsProvider(kCommunityGroupId)),
          ),
        ),
        data: (rounds) {
          if (rounds.isEmpty) {
            return ResponsivePage(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Text('No community goal right now', style: textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Check back soon — new ones get added regularly.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return ResponsivePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final round in rounds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CommunityRoundCard(round: round),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommunityRoundCard extends ConsumerStatefulWidget {
  const _CommunityRoundCard({required this.round});

  final GoalGroupRound round;

  @override
  ConsumerState<_CommunityRoundCard> createState() =>
      _CommunityRoundCardState();
}

class _CommunityRoundCardState extends ConsumerState<_CommunityRoundCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(goalGroupRoundStakesProvider(widget.round.id));
      ref.invalidate(goalGroupLeaderboardProvider(kCommunityGroupId));
    } on GoalGroupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndJoin(GoalGroupRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this goal?'),
        content: const Text(
          "Your stake will be taken from your wallet the moment you accept.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed == true) _run(() => repo.joinRound(widget.round.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.read(goalGroupRepositoryProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final stakesAsync = ref.watch(goalGroupRoundStakesProvider(widget.round.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: stakesAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => Text(
          "Could not load this goal's status.",
          style: textTheme.bodySmall,
        ),
        data: (stakes) {
          final mine = stakes.where((s) => s.userId == currentUserId).toList();
          final myStake = mine.isEmpty ? null : mine.first;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.round.title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'R${widget.round.stakeRand.toStringAsFixed(2)} · '
                '${stakes.length} joined',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_busy)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (myStake == null)
                ElevatedButton(
                  onPressed: () => _confirmAndJoin(repo),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Accept Goal'),
                )
              else if (myStake.outcome != GoalGroupStakeOutcome.pending)
                Text(
                  myStake.outcome == GoalGroupStakeOutcome.completed
                      ? 'You reported: hit it'
                      : 'You reported: missed it',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: myStake.outcome == GoalGroupStakeOutcome.completed
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _run(
                        () => repo.reportOutcome(
                          roundId: widget.round.id,
                          completed: true,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                      child: const Text('I hit it'),
                    ),
                    OutlinedButton(
                      onPressed: () => _run(
                        () => repo.reportOutcome(
                          roundId: widget.round.id,
                          completed: false,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      child: const Text('I missed it'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

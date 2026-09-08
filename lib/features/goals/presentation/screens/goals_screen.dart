import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../league/application/league_providers.dart';
import '../../../league/presentation/screens/league_screen.dart';
import '../../application/goal_providers.dart';
import '../../domain/goal.dart';
import '../widgets/goal_card.dart';
import 'completed_goals_list_screen.dart';
import 'new_goal_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: DockClearFab(
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewGoalScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('New goal'),
        ),
      ),
      body: RefreshIndicator(
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
            error: (error, _) => RetryableError(
              message: 'Could not load goals.',
              onRetry: () => ref.invalidate(goalsProvider),
            ),
            data: (goals) {
              if (goals.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CashPrizeChallengeBanner(),
                    Padding(
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
                    ),
                  ],
                );
              }
              final active = goals
                  .where((g) => g.status == GoalStatus.active)
                  .toList();
              // Everything that's no longer pending — completed is the
              // common case, but failed/cancelled land here too rather
              // than vanishing from the list; GoalCard still shows each
              // one's real status badge.
              final done = goals
                  .where((g) => g.status != GoalStatus.active)
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CashPrizeChallengeBanner(),
                  Text('Active Goals', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (active.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No active goals right now.',
                        style: textTheme.bodySmall,
                      ),
                    )
                  else
                    for (final goal in active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GoalCard(goal: goal),
                      ),
                  const SizedBox(height: 12),
                  Text('Completed Goals', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (done.isEmpty)
                    Text(
                      'Nothing completed yet.',
                      style: textTheme.bodySmall,
                    )
                  else ...[
                    for (final goal in done.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GoalCard(goal: goal),
                      ),
                    if (done.length > 3)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CompletedGoalsListScreen(goals: done),
                          ),
                        ),
                        child: const Text('View more'),
                      ),
                  ],
                  const SizedBox(height: 72), // clear of the FAB
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Links into the current "No Turning Back" league — nothing shows if
/// one's never been created (see the League feature's own founder-only
/// Create League flow). Rendered at the same height as a GoalCard
/// (~88dp) rather than the banner's own aspect ratio, so it sits
/// consistently among the goal cards below it.
class _CashPrizeChallengeBanner extends ConsumerWidget {
  const _CashPrizeChallengeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(currentLeagueProvider).value;
    if (league == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cash Prize Challenges', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Material(
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LeagueScreen(leagueId: league.id)),
              ),
              child: SizedBox(
                height: 88,
                child: Image.asset(
                  'assets/images/no_turning_back_banner.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

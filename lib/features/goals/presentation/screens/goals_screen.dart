import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/goal_providers.dart';
import '../widgets/goal_card.dart';
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
                  for (final goal in goals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GoalCard(goal: goal),
                    ),
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

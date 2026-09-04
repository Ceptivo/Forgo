import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../goals/domain/goal.dart';
import '../../../goals/presentation/widgets/goal_type_card.dart';
import 'start_group_round_details_screen.dart';

/// Pick a goal type to challenge the group with, then fill in the
/// details on that type's own page — same pattern as [NewGoalScreen]
/// for an individual goal.
class StartGroupRoundScreen extends StatelessWidget {
  const StartGroupRoundScreen({super.key, required this.groupId});

  final String groupId;

  void _openDetails(BuildContext context, GoalType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            StartGroupRoundDetailsScreen(groupId: groupId, type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Start a group goal')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Whatever stake you set is what every member pays to join in.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('Choose a goal type', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            GoalTypeCard(
              icon: Icons.directions_run_rounded,
              title: 'Distance',
              subtitle: 'Verified via screenshot',
              description: 'Cover a target distance running, walking, '
                  'cycling, or swimming.',
              selected: false,
              onTap: () => _openDetails(context, GoalType.distance),
            ),
            const SizedBox(height: 10),
            GoalTypeCard(
              icon: Icons.monitor_weight_outlined,
              title: 'Weight loss',
              subtitle: 'Verified via scale photo',
              description: 'Reach a target weight by a deadline you set.',
              selected: false,
              onTap: () => _openDetails(context, GoalType.weightLoss),
            ),
          ],
        ),
      ),
    );
  }
}

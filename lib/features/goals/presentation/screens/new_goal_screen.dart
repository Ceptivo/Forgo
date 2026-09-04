import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../domain/goal.dart';
import '../widgets/goal_type_card.dart';
import 'new_goal_details_screen.dart';

/// Pick a goal type, then fill in the details on that type's own page —
/// tapping a card navigates straight there rather than expanding fields
/// inline beneath all three (unpicked) cards on this same page.
class NewGoalScreen extends StatelessWidget {
  const NewGoalScreen({super.key});

  void _openDetails(BuildContext context, GoalType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewGoalDetailsScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New goal')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              icon: Icons.timer_outlined,
              title: 'Time',
              subtitle: 'Verified via screenshot',
              description: 'Keep moving for a set duration — run for 20 '
                  'min, cycle for an hour, and so on.',
              selected: false,
              onTap: () => _openDetails(context, GoalType.time),
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

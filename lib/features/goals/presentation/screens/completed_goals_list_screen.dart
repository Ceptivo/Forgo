import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/goal.dart';
import '../widgets/goal_card.dart';

enum _GoalCategory { weightLoss, running, cycling, swimming, walking }

const _categoryLabels = {
  _GoalCategory.weightLoss: 'Weight Loss',
  _GoalCategory.running: 'Running',
  _GoalCategory.cycling: 'Cycling',
  _GoalCategory.swimming: 'Swimming',
  _GoalCategory.walking: 'Walking',
};

_GoalCategory? _categoryOf(Goal goal) {
  if (goal.type == GoalType.weightLoss) return _GoalCategory.weightLoss;
  return switch (goal.distanceActivity) {
    DistanceActivity.run => _GoalCategory.running,
    DistanceActivity.cycle => _GoalCategory.cycling,
    DistanceActivity.swim => _GoalCategory.swimming,
    DistanceActivity.walk => _GoalCategory.walking,
    null => null,
  };
}

/// The full "Completed Goals" list — reached from GoalsScreen's "View
/// more", which only shows the latest 3 inline. [goals] is passed in
/// rather than re-fetched, since GoalsScreen already has the full list.
class CompletedGoalsListScreen extends StatefulWidget {
  const CompletedGoalsListScreen({super.key, required this.goals});

  final List<Goal> goals;

  @override
  State<CompletedGoalsListScreen> createState() =>
      _CompletedGoalsListScreenState();
}

class _CompletedGoalsListScreenState extends State<CompletedGoalsListScreen> {
  final _searchController = TextEditingController();
  _GoalCategory? _category;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Order-independent word match, so "10km run" finds "Run 10km".
    final words = _query.trim().isEmpty
        ? const <String>[]
        : _query.trim().toLowerCase().split(RegExp(r'\s+'));

    final filtered = widget.goals.where((goal) {
      if (_category != null && _categoryOf(goal) != _category) return false;
      if (words.isEmpty) return true;
      final title = goal.title.toLowerCase();
      return words.every(title.contains);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Completed Goals')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search, e.g. "10km run"',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final category in _GoalCategory.values)
                  _CategoryChip(
                    label: _categoryLabels[category]!,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No completed goals match.',
                  style: textTheme.bodyMedium,
                ),
              )
            else
              for (final goal in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GoalCard(goal: goal),
                ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentDeep : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

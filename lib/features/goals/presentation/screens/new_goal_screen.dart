import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/goal_providers.dart';
import '../../data/goal_repository.dart';
import '../../domain/goal.dart';
import '../widgets/goal_type_card.dart';
import '../widgets/stake_amount_field.dart';

const _distanceActivityIcons = {
  DistanceActivity.run: Icons.directions_run_rounded,
  DistanceActivity.walk: Icons.directions_walk_rounded,
  DistanceActivity.cycle: Icons.directions_bike_rounded,
  DistanceActivity.swim: Icons.pool_rounded,
};

class NewGoalScreen extends ConsumerStatefulWidget {
  const NewGoalScreen({super.key});

  @override
  ConsumerState<NewGoalScreen> createState() => _NewGoalScreenState();
}

class _NewGoalScreenState extends ConsumerState<NewGoalScreen> {
  GoalType? _type;

  final _distanceController = TextEditingController();
  DistanceCadence _cadence = DistanceCadence.once;
  DistanceActivity _activity = DistanceActivity.run;

  final _targetKgController = TextEditingController();

  DateTime? _deadline;
  int? _stakeCents;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _distanceController.dispose();
    _targetKgController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Goal deadline',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  bool get _canSubmit {
    if (_stakeCents == null) return false;
    if (_type == GoalType.distance) {
      final distance = double.tryParse(_distanceController.text.trim());
      if (distance == null || distance <= 0) return false;
      return _cadence == DistanceCadence.weekly || _deadline != null;
    }
    if (_type == GoalType.weightLoss) {
      final target = double.tryParse(_targetKgController.text.trim());
      return target != null && target > 0 && _deadline != null;
    }
    return false;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repository = ref.read(goalRepositoryProvider);
      if (_type == GoalType.distance) {
        await repository.createDistanceGoal(
          stakeCents: _stakeCents!,
          distanceKm: double.parse(_distanceController.text.trim()),
          cadence: _cadence,
          activity: _activity,
          deadline: _cadence == DistanceCadence.once ? _deadline : null,
        );
      } else {
        await repository.createWeightLossGoal(
          stakeCents: _stakeCents!,
          targetKg: double.parse(_targetKgController.text.trim()),
          deadline: _deadline!,
        );
      }

      ref.invalidate(goalsProvider);
      ref.invalidate(currentProfileProvider);
      if (mounted) context.pop();
    } on GoalException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final balance = ref.watch(currentProfileProvider).value?.walletBalanceCents;

    return Scaffold(
      appBar: AppBar(title: const Text('New goal')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose a goal type', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GoalTypeCard(
                    icon: Icons.directions_run_rounded,
                    title: 'Distance',
                    subtitle: 'Verified via screenshot',
                    selected: _type == GoalType.distance,
                    onTap: () => setState(() {
                      _type = GoalType.distance;
                      _deadline = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoalTypeCard(
                    icon: Icons.monitor_weight_outlined,
                    title: 'Weight loss',
                    subtitle: 'Verified via scale photo',
                    selected: _type == GoalType.weightLoss,
                    onTap: () => setState(() {
                      _type = GoalType.weightLoss;
                      _deadline = null;
                    }),
                  ),
                ),
              ],
            ),
            if (_type == GoalType.distance) ...[
              const SizedBox(height: 24),
              Text('Activity', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final activity in DistanceActivity.values)
                    _ActivityChip(
                      activity: activity,
                      selected: _activity == activity,
                      onTap: () => setState(() => _activity = activity),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Distance', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distance (km)',
                  suffixText: 'km',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('How often', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<DistanceCadence>(
                segments: const [
                  ButtonSegment(
                    value: DistanceCadence.once,
                    label: Text('Once'),
                  ),
                  ButtonSegment(
                    value: DistanceCadence.weekly,
                    label: Text('Every week'),
                  ),
                ],
                selected: {_cadence},
                onSelectionChanged: (selection) =>
                    setState(() => _cadence = selection.first),
              ),
              if (_cadence == DistanceCadence.once) ...[
                const SizedBox(height: 16),
                _DeadlinePicker(deadline: _deadline, onTap: _pickDeadline),
              ],
            ],
            if (_type == GoalType.weightLoss) ...[
              const SizedBox(height: 24),
              Text('Target', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _targetKgController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight to lose (kg)',
                  suffixText: 'kg',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _DeadlinePicker(deadline: _deadline, onTap: _pickDeadline),
            ],
            if (_type != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Stake', style: textTheme.titleMedium),
                  if (balance != null) ...[
                    const Spacer(),
                    Text(
                      'Balance: R${(balance / 100).toStringAsFixed(2)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              StakeAmountField(
                selectedCents: _stakeCents,
                onChanged: (cents) => setState(() => _stakeCents = cents),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: (_canSubmit && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Stake and start'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  final DistanceActivity activity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _distanceActivityIcons[activity],
              size: 18,
              color: selected ? AppColors.accentDeep : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              distanceActivityLabel(activity),
              style: TextStyle(
                color: selected ? AppColors.accentDeep : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinePicker extends StatelessWidget {
  const _DeadlinePicker({required this.deadline, required this.onTap});

  final DateTime? deadline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Deadline',
          suffixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(
          deadline == null
              ? 'Select a deadline'
              : DateFormat.yMMMd().format(deadline!),
          style: deadline == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}

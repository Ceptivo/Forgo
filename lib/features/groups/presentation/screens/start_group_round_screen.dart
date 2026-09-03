import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../goals/domain/goal.dart';
import '../../../goals/presentation/widgets/goal_type_card.dart';
import '../../../goals/presentation/widgets/stake_amount_field.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';

const _distanceActivityIcons = {
  DistanceActivity.run: Icons.directions_run_rounded,
  DistanceActivity.walk: Icons.directions_walk_rounded,
  DistanceActivity.cycle: Icons.directions_bike_rounded,
  DistanceActivity.swim: Icons.pool_rounded,
};

/// Starts a new shared goal ("round") in a group — same form shape as
/// [NewGoalScreen] for an individual goal, but the stake the caller sets
/// here becomes the fixed amount every member who joins in also stakes.
class StartGroupRoundScreen extends ConsumerStatefulWidget {
  const StartGroupRoundScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<StartGroupRoundScreen> createState() =>
      _StartGroupRoundScreenState();
}

class _StartGroupRoundScreenState
    extends ConsumerState<StartGroupRoundScreen> {
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
      final repository = ref.read(goalGroupRepositoryProvider);
      if (_type == GoalType.distance) {
        await repository.startRound(
          groupId: widget.groupId,
          type: GoalType.distance,
          stakeCents: _stakeCents!,
          distanceKm: double.parse(_distanceController.text.trim()),
          distanceCadence: _cadence,
          distanceActivity: _activity,
          deadline: _cadence == DistanceCadence.once ? _deadline : null,
        );
      } else {
        await repository.startRound(
          groupId: widget.groupId,
          type: GoalType.weightLoss,
          stakeCents: _stakeCents!,
          weightLossTargetKg: double.parse(_targetKgController.text.trim()),
          deadline: _deadline!,
        );
      }

      ref.invalidate(goalGroupRoundsProvider(widget.groupId));
      ref.invalidate(goalGroupActiveRoundProvider(widget.groupId));
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } on GoalGroupException catch (e) {
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
              selected: _type == GoalType.distance,
              onTap: () => setState(() {
                _type = GoalType.distance;
                _deadline = null;
              }),
            ),
            const SizedBox(height: 10),
            GoalTypeCard(
              icon: Icons.monitor_weight_outlined,
              title: 'Weight loss',
              subtitle: 'Verified via scale photo',
              description: 'Reach a target weight by a deadline you set.',
              selected: _type == GoalType.weightLoss,
              onTap: () => setState(() {
                _type = GoalType.weightLoss;
                _deadline = null;
              }),
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
                  Text('Stake per member', style: textTheme.titleMedium),
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

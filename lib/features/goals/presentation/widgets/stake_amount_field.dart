import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const _presetsRand = [10, 20, 50, 100, 200];

/// Inline stake-amount picker: the same preset/custom pattern as the
/// wallet's top-up sheet, but embedded directly in the goal creation form
/// rather than a bottom sheet — staking is one step among several here,
/// not a standalone action.
class StakeAmountField extends StatefulWidget {
  const StakeAmountField({
    super.key,
    required this.selectedCents,
    required this.onChanged,
  });

  final int? selectedCents;
  final ValueChanged<int?> onChanged;

  @override
  State<StakeAmountField> createState() => _StakeAmountFieldState();
}

class _StakeAmountFieldState extends State<StakeAmountField> {
  late final _customController = TextEditingController(
    text: widget.selectedCents != null && !_presetsRand.contains(widget.selectedCents! ~/ 100)
        ? (widget.selectedCents! / 100).toStringAsFixed(0)
        : '',
  );

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final rand in _presetsRand)
              _PresetChip(
                rand: rand,
                selected: widget.selectedCents == rand * 100,
                onTap: () {
                  _customController.clear();
                  widget.onChanged(rand * 100);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Custom amount (R)',
            prefixText: 'R ',
          ),
          onChanged: (value) {
            final rand = int.tryParse(value.trim());
            widget.onChanged(rand == null || rand < 10 ? null : rand * 100);
          },
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.rand,
    required this.selected,
    required this.onTap,
  });

  final int rand;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          'R$rand',
          style: TextStyle(
            color: selected ? AppColors.accentDeep : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const _presetsRand = [10, 20, 50, 100, 200];

/// Bottom sheet for picking a top-up amount — the presets from the build
/// plan (R10/20/50/100/200) plus a custom entry. Returns the chosen amount
/// in cents, or null if dismissed without choosing.
Future<int?> showTopUpAmountSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (context) => const _TopUpAmountSheet(),
  );
}

class _TopUpAmountSheet extends StatefulWidget {
  const _TopUpAmountSheet();

  @override
  State<_TopUpAmountSheet> createState() => _TopUpAmountSheetState();
}

class _TopUpAmountSheetState extends State<_TopUpAmountSheet> {
  final _customController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final rand = int.tryParse(_customController.text.trim());
    if (rand == null || rand < 10) {
      setState(() => _error = 'Enter at least R10');
      return;
    }
    if (rand > 5000) {
      setState(() => _error = 'Max top-up is R5,000');
      return;
    }
    Navigator.of(context).pop(rand * 100);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Top up wallet', style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            "Money you add can't be withdrawn yet — it can only be staked "
            'on goals.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final rand in _presetsRand)
                _PresetChip(
                  rand: rand,
                  onTap: () => Navigator.of(context).pop(rand * 100),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Custom amount (R)',
              errorText: _error,
              prefixText: 'R ',
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submitCustom(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitCustom,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.rand, required this.onTap});

  final int rand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          'R$rand',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

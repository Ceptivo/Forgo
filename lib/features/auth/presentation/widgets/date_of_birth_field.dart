import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date-of-birth picker used by the signup form. Keeps the 18+ minimum-age
/// rule in one place (see [minimumAge]) so both the displayed picker range
/// and the "must be 18+" validation stay in sync.
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  static const int minimumAge = 18;

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  static DateTime latestEligibleBirthDate([DateTime? now]) {
    final today = now ?? DateTime.now();
    return DateTime(today.year - minimumAge, today.month, today.day);
  }

  static bool isEligible(DateTime dateOfBirth, [DateTime? now]) {
    return !dateOfBirth.isAfter(latestEligibleBirthDate(now));
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? latestEligibleBirthDate(now),
      firstDate: DateTime(now.year - 100),
      lastDate: latestEligibleBirthDate(now),
      helpText: 'Date of birth',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? null
        : DateFormat.yMMMMd().format(value!);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth',
          errorText: errorText,
          suffixIcon: const Icon(Icons.cake_outlined),
        ),
        child: Text(
          formatted ?? 'Select your date of birth',
          style: formatted == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/league_providers.dart';
import '../../data/league_repository.dart';

/// Founder-only: sets up a new 30-day "No Turning Back" league — its name,
/// start date, entry fee, prize, and all 30 daily goals — in one form.
/// Nothing here is seeded via SQL like the rest of the app's
/// developer-curated content, since the founder wants to set these
/// amounts per league from the app itself rather than the SQL editor.
class CreateLeagueScreen extends ConsumerStatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  ConsumerState<CreateLeagueScreen> createState() =>
      _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends ConsumerState<CreateLeagueScreen> {
  final _nameController = TextEditingController(text: 'No Turning Back');
  final _entryFeeController = TextEditingController();
  final _prizeController = TextEditingController();
  DateTime? _startDate;

  late final _dayTitleControllers = List.generate(
    30,
    (_) => TextEditingController(),
  );
  late final _dayDescriptionControllers = List.generate(
    30,
    (_) => TextEditingController(),
  );

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _entryFeeController.dispose();
    _prizeController.dispose();
    for (final c in _dayTitleControllers) {
      c.dispose();
    }
    for (final c in _dayDescriptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'League start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final entryFeeRand = int.tryParse(_entryFeeController.text.trim());
    final prizeRand = int.tryParse(_prizeController.text.trim());

    if (name.isEmpty || entryFeeRand == null || prizeRand == null || _startDate == null) {
      setState(() => _error = 'Fill in the league name, dates, and amounts.');
      return;
    }
    for (var i = 0; i < 30; i++) {
      if (_dayTitleControllers[i].text.trim().isEmpty ||
          _dayDescriptionControllers[i].text.trim().isEmpty) {
        setState(() => _error = 'Day ${i + 1} needs a title and description.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(leagueRepositoryProvider)
          .createLeague(
            name: name,
            entryFeeCents: entryFeeRand * 100,
            prizeCents: prizeRand * 100,
            startDate: _startDate!,
            days: [
              for (var i = 0; i < 30; i++)
                {
                  'day_number': i + 1,
                  'title': _dayTitleControllers[i].text.trim(),
                  'description': _dayDescriptionControllers[i].text.trim(),
                },
            ],
          );
      ref.invalidate(currentLeagueProvider);
      if (mounted) Navigator.of(context).pop();
    } on LeagueException catch (e) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Create league')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('League details', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'League name'),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickStartDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Start date (day 1 releases 04:00 SAST)',
                suffixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(
                _startDate == null
                    ? 'Select a start date'
                    : DateFormat.yMMMd().format(_startDate!),
                style: _startDate == null
                    ? TextStyle(color: Theme.of(context).hintColor)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _entryFeeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Entry fee (R)',
                    prefixText: 'R ',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _prizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prize (R)',
                    prefixText: 'R ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The entry fee is a non-refundable gate cost. The prize is '
            "funded directly by Forgo, not the entry fees, and is credited "
            "to the winner's wallet once you finalize the league.",
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          Text('The 30 daily goals', style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Each one releases automatically at 04:00 SAST on its day.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 30; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day ${i + 1}', style: textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dayTitleControllers[i],
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dayDescriptionControllers[i],
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create league'),
          ),
        ],
      ),
    );
  }
}

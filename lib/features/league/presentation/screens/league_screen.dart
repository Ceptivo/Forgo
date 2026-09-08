import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/league_providers.dart';
import '../../data/league_repository.dart';
import '../../domain/league.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/league_standing_row.dart';

class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key, required this.leagueId});

  final String leagueId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(leagueByIdProvider(leagueId));
    ref.invalidate(leagueReleasedDaysProvider(leagueId));
    ref.invalidate(leagueEntriesProvider(leagueId));
    ref.invalidate(leagueSubmissionsProvider(leagueId));
    ref.invalidate(leagueStandingsProvider(leagueId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagueAsync = ref.watch(leagueByIdProvider(leagueId));

    return Scaffold(
      appBar: AppBar(title: Text(leagueAsync.value?.name ?? 'League')),
      body: leagueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: RetryableError(
            message: 'Could not load this league.',
            onRetry: () => _refresh(ref),
          ),
        ),
        data: (league) => _LeagueBody(league: league, onChanged: () => _refresh(ref)),
      ),
    );
  }
}

class _LeagueBody extends ConsumerWidget {
  const _LeagueBody({required this.league, required this.onChanged});

  final League league;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now().toUtc();
    final daysAsync = ref.watch(leagueReleasedDaysProvider(league.id));
    final entriesAsync = ref.watch(leagueEntriesProvider(league.id));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!league.hasStarted(now))
            _UpcomingSection(league: league, onChanged: onChanged)
          else if (!league.hasFinished(now))
            daysAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text("Couldn't load today's goal."),
              data: (days) => _ActiveSection(
                league: league,
                days: days,
                joined:
                    entriesAsync.value?.any((e) => e.userId == currentUserId) ??
                    false,
                onChanged: onChanged,
              ),
            )
          else
            _FinishedSection(league: league, onChanged: onChanged),
          const SizedBox(height: 28),
          Text('Standings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _StandingsList(leagueId: league.id),
          const SizedBox(height: DockClearFab.clearance),
        ],
      ),
    );
  }
}

class _UpcomingSection extends ConsumerStatefulWidget {
  const _UpcomingSection({required this.league, required this.onChanged});

  final League league;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UpcomingSection> createState() => _UpcomingSectionState();
}

class _UpcomingSectionState extends ConsumerState<_UpcomingSection> {
  bool _joining = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(leagueRepositoryProvider).joinLeague(widget.league.id);
      widget.onChanged();
    } on LeagueException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entriesAsync = ref.watch(leagueEntriesProvider(widget.league.id));
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final joined =
        entriesAsync.value?.any((e) => e.userId == currentUserId) ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('30 days. No turning back.', style: textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Starts ${DateFormat.yMMMd().format(widget.league.startDate)} at '
            '04:00. Miss a single day and you\'re out — survive all 30 to '
            'be in the running for the prize.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _AmountPill(
                label: 'Entry',
                rand: widget.league.entryFeeRand,
              ),
              const SizedBox(width: 10),
              _AmountPill(
                label: 'Prize',
                rand: widget.league.prizeRand,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (joined)
            const Text(
              "You're entered — come back once it starts.",
              style: TextStyle(fontWeight: FontWeight.w700),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _joining ? null : _join,
                child: _joining
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Join for R${widget.league.entryFeeRand.toStringAsFixed(0)}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveSection extends ConsumerStatefulWidget {
  const _ActiveSection({
    required this.league,
    required this.days,
    required this.joined,
    required this.onChanged,
  });

  final League league;
  final List<LeagueDay> days;
  final bool joined;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ActiveSection> createState() => _ActiveSectionState();
}

class _ActiveSectionState extends ConsumerState<_ActiveSection> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit(int dayNumber, bool completed) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(leagueRepositoryProvider)
          .submitDay(
            leagueId: widget.league.id,
            dayNumber: dayNumber,
            completed: completed,
          );
      widget.onChanged();
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
    if (widget.days.isEmpty) {
      return const Text("Today's goal hasn't dropped yet.");
    }
    final today = widget.days.last;
    final submissionsAsync = ref.watch(
      leagueSubmissionsProvider(widget.league.id),
    );
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final matchingSubmissions = submissionsAsync.value
        ?.where((s) => s.userId == currentUserId && s.dayNumber == today.dayNumber)
        .toList();
    final mySubmission = (matchingSubmissions == null || matchingSubmissions.isEmpty)
        ? null
        : matchingSubmissions.first;
    final nextRelease = widget.league.releaseAt(today.dayNumber + 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day ${today.dayNumber} of 30', style: textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(today.title, style: textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(today.description, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (!widget.joined)
            const Text(
              'This league has already started, so you can no longer join.',
              style: TextStyle(fontWeight: FontWeight.w700),
            )
          else if (mySubmission != null)
            Text(
              mySubmission.completed
                  ? "You're in for today — next goal in:"
                  : 'You reported missing today. Next goal in:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: mySubmission.completed
                    ? AppColors.success
                    : AppColors.danger,
              ),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            if (_submitting)
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _submit(today.dayNumber, true),
                      child: const Text('I did it'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submit(today.dayNumber, false),
                      child: const Text('I missed it'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text('Next goal drops in:', style: textTheme.bodySmall),
          ],
          if (widget.joined) ...[
            const SizedBox(height: 6),
            CountdownTimer(target: nextRelease, onZero: widget.onChanged),
          ],
        ],
      ),
    );
  }
}

class _FinishedSection extends ConsumerStatefulWidget {
  const _FinishedSection({required this.league, required this.onChanged});

  final League league;
  final VoidCallback onChanged;

  @override
  ConsumerState<_FinishedSection> createState() => _FinishedSectionState();
}

class _FinishedSectionState extends ConsumerState<_FinishedSection> {
  bool _finalizing = false;
  String? _error;

  Future<void> _finalize() async {
    setState(() {
      _finalizing = true;
      _error = null;
    });
    try {
      await ref.read(leagueRepositoryProvider).finalizeLeague(widget.league.id);
      widget.onChanged();
    } on LeagueException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isFounderAsync = ref.watch(isForgoFounderProvider);
    final namesAsync = ref.watch(leagueMemberNamesProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This league has finished', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          if (widget.league.isFinalized)
            Text(
              widget.league.winnerUserId == null
                  ? 'Nobody completed all 30 days — no winner this round.'
                  : '${namesAsync.value?[widget.league.winnerUserId] ?? 'Someone'} '
                        'won R${widget.league.prizeRand.toStringAsFixed(0)}!',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            )
          else if (isFounderAsync.value == true) ...[
            Text(
              'Finalize to determine the winner and pay out the prize.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finalizing ? null : _finalize,
                child: _finalizing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finalize & pay winner'),
              ),
            ),
          ] else
            Text('Results are being finalized.', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StandingsList extends ConsumerWidget {
  const _StandingsList({required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(leagueStandingsProvider(leagueId));
    final namesAsync = ref.watch(leagueMemberNamesProvider);

    return standingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Text('Could not load standings.'),
      data: (standings) {
        if (standings.isEmpty) {
          return Text(
            'Nobody has joined yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return Column(
          children: [
            for (var i = 0; i < standings.length; i++)
              LeagueStandingRow(
                rank: i + 1,
                name: namesAsync.value?[standings[i].userId] ?? 'Member',
                standing: standings[i],
              ),
          ],
        );
      },
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.label,
    required this.rand,
    this.highlight = false,
  });

  final String label;
  final double rand;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accentDim : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            'R${rand.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: highlight ? AppColors.accentDeep : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

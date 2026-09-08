import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../groups/application/goal_group_providers.dart';
import '../data/league_repository.dart';
import '../domain/league.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return LeagueRepository(ref.watch(supabaseClientProvider));
});

final isForgoFounderProvider = FutureProvider.autoDispose<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref.watch(leagueRepositoryProvider).isFounder();
});

/// The most recently created league — null once none has ever been made.
final currentLeagueProvider = FutureProvider.autoDispose<League?>((ref) {
  return ref.watch(leagueRepositoryProvider).fetchCurrentLeague();
});

final leagueByIdProvider = FutureProvider.autoDispose.family<League, String>((
  ref,
  leagueId,
) {
  return ref.watch(leagueRepositoryProvider).fetchLeague(leagueId);
});

final leagueReleasedDaysProvider = FutureProvider.autoDispose
    .family<List<LeagueDay>, String>((ref, leagueId) {
      return ref.watch(leagueRepositoryProvider).fetchReleasedDays(leagueId);
    });

final leagueEntriesProvider = FutureProvider.autoDispose
    .family<List<LeagueEntry>, String>((ref, leagueId) {
      return ref.watch(leagueRepositoryProvider).fetchEntries(leagueId);
    });

final leagueSubmissionsProvider = FutureProvider.autoDispose
    .family<List<LeagueSubmission>, String>((ref, leagueId) {
      return ref.watch(leagueRepositoryProvider).fetchSubmissions(leagueId);
    });

/// Names for every league entrant — every user is auto-joined to the
/// Forgo Community Group (0015_community.sql), so its member-names RPC
/// already covers anyone who could possibly have entered a league.
final leagueMemberNamesProvider = FutureProvider.autoDispose<
  Map<String, String>
>((ref) {
  return ref.watch(goalGroupMemberNamesProvider(kCommunityGroupId).future);
});

final leagueStandingsProvider = FutureProvider.autoDispose
    .family<List<LeagueStanding>, String>((ref, leagueId) async {
      final league = await ref.watch(leagueByIdProvider(leagueId).future);
      final entries = await ref.watch(
        leagueEntriesProvider(leagueId).future,
      );
      final submissions = await ref.watch(
        leagueSubmissionsProvider(leagueId).future,
      );
      return computeLeagueStandings(
        league: league,
        entries: entries,
        submissions: submissions,
        now: DateTime.now().toUtc(),
      );
    });

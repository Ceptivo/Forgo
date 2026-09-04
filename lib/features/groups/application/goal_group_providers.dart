import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/goal_group_repository.dart';
import '../domain/goal_group.dart';
import '../domain/goal_group_invite.dart';
import '../domain/goal_group_leaderboard_entry.dart';
import '../domain/goal_group_message.dart';
import '../domain/goal_group_round.dart';
import '../domain/goal_group_stake.dart';

/// Fixed id of the Forgo community "group" — see 0015_community.sql.
/// Every user is a member of it automatically; it's built entirely on
/// the same goal_groups/goal_group_goals/goal_group_stakes machinery as
/// a normal group, just with no chat and (unlike every other group)
/// more than one active round allowed at once, so a daily and a weekly
/// community goal can run side by side.
const kCommunityGroupId = '00000000-0000-0000-0000-000000000001';

final goalGroupRepositoryProvider = Provider<GoalGroupRepository>((ref) {
  return GoalGroupRepository(ref.watch(supabaseClientProvider));
});

final myGoalGroupsProvider = FutureProvider.autoDispose<List<GoalGroup>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(goalGroupRepositoryProvider).fetchMyGroups();
});

/// Pending invites addressed to the caller — updates live as new invites
/// land or existing ones are responded to (e.g. from another device).
final myGoalGroupInvitesProvider =
    StreamProvider.autoDispose<List<GoalGroupInvite>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user == null) return Stream.value(const []);
      return ref.watch(goalGroupRepositoryProvider).watchMyInvites();
    });

/// A single group's live row — name/bio/image can change after the
/// GoalGroup a screen was pushed with was fetched, so anywhere that
/// displays or edits those should watch this rather than trust a
/// possibly-stale constructor value.
final goalGroupByIdProvider = FutureProvider.autoDispose
    .family<GoalGroup, String>((ref, groupId) {
      return ref.watch(goalGroupRepositoryProvider).fetchGroup(groupId);
    });

final goalGroupRoundsProvider = FutureProvider.autoDispose
    .family<List<GoalGroupRound>, String>((ref, groupId) {
      return ref.watch(goalGroupRepositoryProvider).fetchRounds(groupId);
    });

/// The group's currently active round (there is at most one — enforced in
/// the DB), or null if nobody has started one yet.
final goalGroupActiveRoundProvider = FutureProvider.autoDispose
    .family<GoalGroupRound?, String>((ref, groupId) async {
      final rounds = await ref.watch(goalGroupRoundsProvider(groupId).future);
      for (final round in rounds) {
        if (round.status == GoalGroupRoundStatus.active) return round;
      }
      return null;
    });

/// Every currently-active round for a group — plural, unlike
/// [goalGroupActiveRoundProvider], since the community group (and only
/// the community group) can have more than one active round at once.
final goalGroupActiveRoundsProvider = FutureProvider.autoDispose
    .family<List<GoalGroupRound>, String>((ref, groupId) async {
      final rounds = await ref.watch(goalGroupRoundsProvider(groupId).future);
      return rounds
          .where((r) => r.status == GoalGroupRoundStatus.active)
          .toList();
    });

final goalGroupRoundStakesProvider = FutureProvider.autoDispose
    .family<List<GoalGroupStake>, String>((ref, roundId) {
      return ref.watch(goalGroupRepositoryProvider).fetchStakesForRound(roundId);
    });

final goalGroupMemberNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, groupId) {
      return ref.watch(goalGroupRepositoryProvider).fetchMemberNames(groupId);
    });

final goalGroupMessagesProvider = StreamProvider.autoDispose
    .family<List<GoalGroupMessage>, String>((ref, groupId) {
      return ref.watch(goalGroupRepositoryProvider).watchMessages(groupId);
    });

class _Agg {
  int completions = 0;
  int fails = 0;
  int wonCents = 0;
  int lostCents = 0;
}

/// Ranks members by completions (most first), then by fewest fails,
/// mirroring the "fittest / most consistent member" framing.
final goalGroupLeaderboardProvider = FutureProvider.autoDispose
    .family<List<GoalGroupLeaderboardEntry>, String>((ref, groupId) async {
      final repo = ref.watch(goalGroupRepositoryProvider);
      final stakes = await repo.fetchStakes(groupId);
      final names = await repo.fetchMemberNames(groupId);

      final byUser = <String, _Agg>{};
      for (final stake in stakes) {
        final agg = byUser.putIfAbsent(stake.userId, () => _Agg());
        switch (stake.outcome) {
          case GoalGroupStakeOutcome.completed:
            agg.completions++;
            agg.wonCents += stake.stakeCents;
          case GoalGroupStakeOutcome.failed:
            agg.fails++;
            agg.lostCents += stake.stakeCents;
          case GoalGroupStakeOutcome.pending:
            break;
        }
      }

      final entries =
          byUser.entries
              .map(
                (e) => GoalGroupLeaderboardEntry(
                  userId: e.key,
                  fullName: names[e.key] ?? 'Member',
                  completions: e.value.completions,
                  fails: e.value.fails,
                  wonCents: e.value.wonCents,
                  lostCents: e.value.lostCents,
                ),
              )
              .toList()
            ..sort((a, b) {
              final byCompletions = b.completions.compareTo(a.completions);
              if (byCompletions != 0) return byCompletions;
              return a.fails.compareTo(b.fails);
            });
      return entries;
    });

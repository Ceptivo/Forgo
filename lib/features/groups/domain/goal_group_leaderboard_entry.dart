/// One row of a group's leaderboard, aggregated client-side from every
/// resolved [GoalGroupStake] a member has taken part in across all of
/// that group's rounds.
class GoalGroupLeaderboardEntry {
  const GoalGroupLeaderboardEntry({
    required this.userId,
    required this.fullName,
    required this.completions,
    required this.fails,
    required this.wonCents,
    required this.lostCents,
  });

  final String userId;
  final String fullName;
  final int completions;
  final int fails;
  final int wonCents;
  final int lostCents;

  double get wonRand => wonCents / 100;
  double get lostRand => lostCents / 100;
}

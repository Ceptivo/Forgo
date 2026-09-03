enum GoalGroupStakeOutcome { pending, completed, failed }

/// One member's stake in one [GoalGroupRound] — pending until they
/// self-report an outcome, at which point it also becomes one data point
/// in the group's leaderboard.
class GoalGroupStake {
  const GoalGroupStake({
    required this.roundId,
    required this.userId,
    required this.stakeCents,
    required this.outcome,
    required this.createdAt,
    this.resolvedAt,
  });

  factory GoalGroupStake.fromMap(Map<String, dynamic> map) {
    return GoalGroupStake(
      roundId: map['goal_group_goal_id'] as String,
      userId: map['user_id'] as String,
      stakeCents: (map['stake_cents'] as num).toInt(),
      outcome: GoalGroupStakeOutcome.values.firstWhere(
        (o) => o.name == map['outcome'],
        orElse: () => GoalGroupStakeOutcome.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.parse(map['resolved_at'] as String),
    );
  }

  final String roundId;
  final String userId;
  final int stakeCents;
  final GoalGroupStakeOutcome outcome;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  double get stakeRand => stakeCents / 100;
}

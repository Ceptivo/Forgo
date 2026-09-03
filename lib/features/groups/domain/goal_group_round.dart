import '../../goals/domain/goal.dart';

enum GoalGroupRoundStatus { active, resolved }

/// One shared goal "round" within a group — every member who joins it
/// stakes the same [stakeCents]. Mirrors the shape of an individual
/// [Goal], minus a single owning user (see [GoalGroupStake] for that).
class GoalGroupRound {
  const GoalGroupRound({
    required this.id,
    required this.groupId,
    required this.startedBy,
    required this.type,
    required this.status,
    required this.stakeCents,
    required this.createdAt,
    this.distanceKm,
    this.distanceCadence,
    this.distanceActivity,
    this.weightLossTargetKg,
    this.deadline,
    this.resolvedAt,
  });

  factory GoalGroupRound.fromMap(Map<String, dynamic> map) {
    return GoalGroupRound(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      startedBy: map['started_by'] as String,
      type: goalTypeFromString(map['type'] as String),
      status: map['status'] == 'resolved'
          ? GoalGroupRoundStatus.resolved
          : GoalGroupRoundStatus.active,
      stakeCents: (map['stake_cents'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      distanceCadence: distanceCadenceFromString(
        map['distance_cadence'] as String?,
      ),
      distanceActivity: distanceActivityFromString(
        map['distance_activity'] as String?,
      ),
      weightLossTargetKg: (map['weight_loss_target_kg'] as num?)?.toDouble(),
      deadline: map['deadline'] == null
          ? null
          : DateTime.parse(map['deadline'] as String),
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.parse(map['resolved_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String startedBy;
  final GoalType type;
  final GoalGroupRoundStatus status;
  final int stakeCents;
  final DateTime createdAt;
  final double? distanceKm;
  final DistanceCadence? distanceCadence;
  final DistanceActivity? distanceActivity;
  final double? weightLossTargetKg;
  final DateTime? deadline;
  final DateTime? resolvedAt;

  double get stakeRand => stakeCents / 100;

  String get title {
    if (type == GoalType.distance) {
      final distance = distanceKm?.toStringAsFixed(
        distanceKm! % 1 == 0 ? 0 : 1,
      );
      final verb = distanceActivityVerb(
        distanceActivity ?? DistanceActivity.run,
      );
      return distanceCadence == DistanceCadence.weekly
          ? '$verb ${distance}km per week'
          : '$verb ${distance}km';
    }
    final target = weightLossTargetKg?.toStringAsFixed(
      weightLossTargetKg! % 1 == 0 ? 0 : 1,
    );
    return 'Lose ${target}kg';
  }
}

enum GoalType { distance, weightLoss, time }

enum GoalStatus { active, completed, failed, cancelled }

enum DistanceCadence { once, weekly }

/// The activity a distance goal is verified against — all four are
/// checked the same way (a screenshot from whatever fitness app the user
/// already uses), so they're one goal type with an activity choice rather
/// than four separate goal types.
enum DistanceActivity { run, walk, cycle, swim }

GoalType goalTypeFromString(String value) => switch (value) {
  'weight_loss' => GoalType.weightLoss,
  'time' => GoalType.time,
  _ => GoalType.distance,
};

String goalTypeToString(GoalType type) => switch (type) {
  GoalType.weightLoss => 'weight_loss',
  GoalType.time => 'time',
  GoalType.distance => 'distance',
};

DistanceCadence? distanceCadenceFromString(String? value) => switch (value) {
  'weekly' => DistanceCadence.weekly,
  'once' => DistanceCadence.once,
  _ => null,
};

String distanceCadenceToString(DistanceCadence cadence) =>
    cadence == DistanceCadence.weekly ? 'weekly' : 'once';

DistanceActivity? distanceActivityFromString(String? value) => switch (value) {
  'walk' => DistanceActivity.walk,
  'cycle' => DistanceActivity.cycle,
  'swim' => DistanceActivity.swim,
  'run' => DistanceActivity.run,
  _ => null,
};

String distanceActivityToString(DistanceActivity activity) => switch (activity) {
  DistanceActivity.run => 'run',
  DistanceActivity.walk => 'walk',
  DistanceActivity.cycle => 'cycle',
  DistanceActivity.swim => 'swim',
};

String distanceActivityLabel(DistanceActivity activity) => switch (activity) {
  DistanceActivity.run => 'Run',
  DistanceActivity.walk => 'Walk',
  DistanceActivity.cycle => 'Cycle',
  DistanceActivity.swim => 'Swim',
};

/// The verb form used in a goal's title, e.g. "Run 5km" vs "Swim 2km".
String distanceActivityVerb(DistanceActivity activity) => switch (activity) {
  DistanceActivity.run => 'Run',
  DistanceActivity.walk => 'Walk',
  DistanceActivity.cycle => 'Cycle',
  DistanceActivity.swim => 'Swim',
};

class Goal {
  const Goal({
    required this.id,
    required this.type,
    required this.status,
    required this.stakeCents,
    required this.createdAt,
    this.distanceKm,
    this.distanceCadence,
    this.distanceActivity,
    this.weightLossTargetKg,
    this.timeMinutes,
    this.deadline,
  });

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String,
      type: goalTypeFromString(map['type'] as String),
      status: GoalStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GoalStatus.active,
      ),
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
      timeMinutes: (map['time_minutes'] as num?)?.toInt(),
      deadline: map['deadline'] == null
          ? null
          : DateTime.parse(map['deadline'] as String),
    );
  }

  final String id;
  final GoalType type;
  final GoalStatus status;
  final int stakeCents;
  final DateTime createdAt;
  final double? distanceKm;
  final DistanceCadence? distanceCadence;
  final DistanceActivity? distanceActivity;
  final double? weightLossTargetKg;
  final int? timeMinutes;
  final DateTime? deadline;

  double get stakeRand => stakeCents / 100;

  String get title {
    switch (type) {
      case GoalType.distance:
        final distance = distanceKm?.toStringAsFixed(
          distanceKm! % 1 == 0 ? 0 : 1,
        );
        final verb = distanceActivityVerb(distanceActivity ?? DistanceActivity.run);
        return distanceCadence == DistanceCadence.weekly
            ? '$verb ${distance}km per week'
            : '$verb ${distance}km';
      case GoalType.time:
        final verb = distanceActivityVerb(distanceActivity ?? DistanceActivity.run);
        final duration = formatGoalDuration(timeMinutes ?? 0);
        return distanceCadence == DistanceCadence.weekly
            ? '$verb for $duration per week'
            : '$verb for $duration';
      case GoalType.weightLoss:
        final target = weightLossTargetKg?.toStringAsFixed(
          weightLossTargetKg! % 1 == 0 ? 0 : 1,
        );
        return 'Lose ${target}kg';
    }
  }
}

/// Formats a minute count the way a person would say it — "20 min",
/// "1 hour", "1.5 hours" — rather than always "90 min".
String formatGoalDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes / 60;
  final rounded = hours % 1 == 0 ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
  return '$rounded ${hours == 1 ? 'hour' : 'hours'}';
}

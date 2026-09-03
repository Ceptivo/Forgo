enum GoalType { run, weightLoss }

enum GoalStatus { active, completed, failed, cancelled }

enum RunCadence { once, weekly }

GoalType goalTypeFromString(String value) =>
    value == 'weight_loss' ? GoalType.weightLoss : GoalType.run;

String goalTypeToString(GoalType type) =>
    type == GoalType.weightLoss ? 'weight_loss' : 'run';

RunCadence? runCadenceFromString(String? value) => switch (value) {
  'weekly' => RunCadence.weekly,
  'once' => RunCadence.once,
  _ => null,
};

String runCadenceToString(RunCadence cadence) =>
    cadence == RunCadence.weekly ? 'weekly' : 'once';

class Goal {
  const Goal({
    required this.id,
    required this.type,
    required this.status,
    required this.stakeCents,
    required this.createdAt,
    this.runDistanceKm,
    this.runCadence,
    this.weightLossTargetKg,
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
      runDistanceKm: (map['run_distance_km'] as num?)?.toDouble(),
      runCadence: runCadenceFromString(map['run_cadence'] as String?),
      weightLossTargetKg: (map['weight_loss_target_kg'] as num?)?.toDouble(),
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
  final double? runDistanceKm;
  final RunCadence? runCadence;
  final double? weightLossTargetKg;
  final DateTime? deadline;

  double get stakeRand => stakeCents / 100;

  String get title {
    if (type == GoalType.run) {
      final distance = runDistanceKm?.toStringAsFixed(
        runDistanceKm! % 1 == 0 ? 0 : 1,
      );
      return runCadence == RunCadence.weekly
          ? 'Run ${distance}km per week'
          : 'Run ${distance}km';
    }
    final target = weightLossTargetKg?.toStringAsFixed(
      weightLossTargetKg! % 1 == 0 ? 0 : 1,
    );
    return 'Lose ${target}kg';
  }
}

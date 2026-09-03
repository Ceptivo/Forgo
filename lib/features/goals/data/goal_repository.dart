import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/goal.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class GoalRepository {
  GoalRepository(this._client);

  final SupabaseClient _client;

  Future<List<Goal>> fetchGoals(String userId) async {
    final rows = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);
    return rows.map(Goal.fromMap).toList();
  }

  /// Atomically deducts [stakeCents] from the caller's wallet and creates
  /// the goal, via the create_goal_with_stake Postgres function — never as
  /// two separate client calls, which could leave a goal without its
  /// stake (or vice versa) if one step failed.
  Future<Goal> createDistanceGoal({
    required int stakeCents,
    required double distanceKm,
    required DistanceCadence cadence,
    required DistanceActivity activity,
    DateTime? deadline,
  }) async {
    return _createGoal(
      type: GoalType.distance,
      stakeCents: stakeCents,
      deadline: deadline,
      distanceKm: distanceKm,
      distanceCadence: cadence,
      distanceActivity: activity,
    );
  }

  Future<Goal> createWeightLossGoal({
    required int stakeCents,
    required double targetKg,
    required DateTime deadline,
  }) async {
    return _createGoal(
      type: GoalType.weightLoss,
      stakeCents: stakeCents,
      deadline: deadline,
      weightLossTargetKg: targetKg,
    );
  }

  Future<Goal> createTimeGoal({
    required int stakeCents,
    required int timeMinutes,
    required DistanceCadence cadence,
    required DistanceActivity activity,
    DateTime? deadline,
  }) async {
    return _createGoal(
      type: GoalType.time,
      stakeCents: stakeCents,
      deadline: deadline,
      distanceCadence: cadence,
      distanceActivity: activity,
      timeMinutes: timeMinutes,
    );
  }

  Future<Goal> _createGoal({
    required GoalType type,
    required int stakeCents,
    DateTime? deadline,
    double? distanceKm,
    DistanceCadence? distanceCadence,
    DistanceActivity? distanceActivity,
    double? weightLossTargetKg,
    int? timeMinutes,
  }) async {
    try {
      final result = await _client.rpc(
        'create_goal_with_stake',
        params: {
          'p_type': goalTypeToString(type),
          'p_stake_cents': stakeCents,
          'p_deadline': deadline == null
              ? null
              : DateFormat('yyyy-MM-dd').format(deadline),
          'p_distance_km': distanceKm,
          'p_distance_cadence': distanceCadence == null
              ? null
              : distanceCadenceToString(distanceCadence),
          'p_distance_activity': distanceActivity == null
              ? null
              : distanceActivityToString(distanceActivity),
          'p_weight_loss_target_kg': weightLossTargetKg,
          'p_time_minutes': timeMinutes,
        },
      ).timeout(_networkTimeout);
      return Goal.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      if (e.message.contains('Insufficient wallet balance')) {
        throw const InsufficientBalanceException();
      }
      throw GoalException(e.message);
    }
  }
}

class GoalException implements Exception {
  const GoalException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InsufficientBalanceException extends GoalException {
  const InsufficientBalanceException()
    : super('Not enough in your wallet — top up first.');
}

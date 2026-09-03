import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/goal.dart';

class GoalRepository {
  GoalRepository(this._client);

  final SupabaseClient _client;

  Future<List<Goal>> fetchGoals(String userId) async {
    final rows = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(Goal.fromMap).toList();
  }

  /// Atomically deducts [stakeCents] from the caller's wallet and creates
  /// the goal, via the create_goal_with_stake Postgres function — never as
  /// two separate client calls, which could leave a goal without its
  /// stake (or vice versa) if one step failed.
  Future<Goal> createRunGoal({
    required int stakeCents,
    required double distanceKm,
    required RunCadence cadence,
    DateTime? deadline,
  }) async {
    return _createGoal(
      type: GoalType.run,
      stakeCents: stakeCents,
      deadline: deadline,
      runDistanceKm: distanceKm,
      runCadence: cadence,
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

  Future<Goal> _createGoal({
    required GoalType type,
    required int stakeCents,
    DateTime? deadline,
    double? runDistanceKm,
    RunCadence? runCadence,
    double? weightLossTargetKg,
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
          'p_run_distance_km': runDistanceKm,
          'p_run_cadence': runCadence == null
              ? null
              : runCadenceToString(runCadence),
          'p_weight_loss_target_kg': weightLossTargetKg,
        },
      );
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

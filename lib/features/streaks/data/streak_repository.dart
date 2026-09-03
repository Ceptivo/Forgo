import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_check_in.dart';
import '../domain/streak_summary.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class StreakRepository {
  StreakRepository(this._client);

  final SupabaseClient _client;

  Future<StreakSummary> fetchSummary(String userId) async {
    final rows = (await _client
            .rpc('get_streak_summary', params: {'p_user_id': userId})
            .timeout(_networkTimeout))
        as List;
    if (rows.isEmpty) {
      return const StreakSummary(
        currentDailyStreak: 0,
        currentWeeklyStreak: 0,
        longestWeeklyStreak: 0,
        last7Days: [],
      );
    }
    return StreakSummary.fromMap(rows.first as Map<String, dynamic>);
  }

  /// The check-in history behind the heatmap — a plain owner-scoped read,
  /// no RPC needed since RLS already limits this to the caller's own rows.
  Future<List<ActivityCheckIn>> fetchHistory({
    required String userId,
    required DateTime since,
  }) async {
    final rows = await _client
        .from('activity_check_ins')
        .select()
        .eq('user_id', userId)
        .gte('logged_date', _isoDate(since))
        .order('logged_date')
        .timeout(_networkTimeout);
    return rows.map(ActivityCheckIn.fromMap).toList();
  }

  String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

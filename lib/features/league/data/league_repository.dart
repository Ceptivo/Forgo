import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/league.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class LeagueRepository {
  LeagueRepository(this._client);

  final SupabaseClient _client;

  Future<bool> isFounder() async {
    final result = await _client
        .rpc('is_forgo_founder')
        .timeout(_networkTimeout);
    return result as bool;
  }

  /// The most recently created league, if any — used for both "the
  /// current/upcoming league" and, once finished, "the last one that ran".
  Future<League?> fetchCurrentLeague() async {
    final rows = await _client
        .from('leagues')
        .select()
        .order('start_date', ascending: false)
        .limit(1)
        .timeout(_networkTimeout);
    if (rows.isEmpty) return null;
    return League.fromMap(rows.first);
  }

  Future<League> fetchLeague(String leagueId) async {
    final row = await _client
        .from('leagues')
        .select()
        .eq('id', leagueId)
        .single()
        .timeout(_networkTimeout);
    return League.fromMap(row);
  }

  /// Only days that have already been released come back — RLS hides the
  /// rest, so there's nothing to filter client-side.
  Future<List<LeagueDay>> fetchReleasedDays(String leagueId) async {
    final rows = await _client
        .from('league_days')
        .select()
        .eq('league_id', leagueId)
        .order('day_number')
        .timeout(_networkTimeout);
    return rows.map(LeagueDay.fromMap).toList();
  }

  Future<List<LeagueEntry>> fetchEntries(String leagueId) async {
    final rows = await _client
        .from('league_entries')
        .select()
        .eq('league_id', leagueId)
        .timeout(_networkTimeout);
    return rows.map(LeagueEntry.fromMap).toList();
  }

  Future<List<LeagueSubmission>> fetchSubmissions(String leagueId) async {
    final rows = await _client
        .from('league_submissions')
        .select()
        .eq('league_id', leagueId)
        .timeout(_networkTimeout);
    return rows.map(LeagueSubmission.fromMap).toList();
  }

  /// [days] must be exactly 30 maps of {day_number, title, description}.
  Future<League> createLeague({
    required String name,
    required int entryFeeCents,
    required int prizeCents,
    required DateTime startDate,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final result = await _client
          .rpc(
            'create_league',
            params: {
              'p_name': name,
              'p_entry_fee_cents': entryFeeCents,
              'p_prize_cents': prizeCents,
              'p_start_date':
                  '${startDate.year.toString().padLeft(4, '0')}-'
                  '${startDate.month.toString().padLeft(2, '0')}-'
                  '${startDate.day.toString().padLeft(2, '0')}',
              'p_days': days,
            },
          )
          .timeout(_networkTimeout);
      return League.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw LeagueException(e.message);
    }
  }

  Future<void> joinLeague(String leagueId) async {
    try {
      await _client
          .rpc('join_league', params: {'p_league_id': leagueId})
          .timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      throw LeagueException(e.message);
    }
  }

  Future<void> submitDay({
    required String leagueId,
    required int dayNumber,
    required bool completed,
  }) async {
    try {
      await _client
          .rpc(
            'submit_league_day',
            params: {
              'p_league_id': leagueId,
              'p_day_number': dayNumber,
              'p_completed': completed,
            },
          )
          .timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      throw LeagueException(e.message);
    }
  }

  Future<League> finalizeLeague(String leagueId) async {
    try {
      final result = await _client
          .rpc('finalize_league', params: {'p_league_id': leagueId})
          .timeout(_networkTimeout);
      return League.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw LeagueException(e.message);
    }
  }
}

class LeagueException implements Exception {
  const LeagueException(this.message);

  final String message;

  @override
  String toString() => message;
}

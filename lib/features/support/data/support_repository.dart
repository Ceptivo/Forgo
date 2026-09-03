import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/charity.dart';
import '../domain/feature_candidate.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class SupportRepository {
  SupportRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitFeedback({
    required String kind,
    required String title,
    required String description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const SupportException('Not authenticated');
    try {
      await _client
          .from('feedback_items')
          .insert({
            'user_id': userId,
            'kind': kind,
            'title': title,
            'description': description,
          })
          .timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      throw SupportException(e.message);
    }
  }

  Future<List<FeatureCandidate>> fetchFeatureCandidates() async {
    final rows = await _client
        .rpc('get_feature_candidates')
        .timeout(_networkTimeout);
    return (rows as List)
        .map((row) => FeatureCandidate.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> castFeatureVote(String candidateId) async {
    try {
      await _client
          .rpc('cast_feature_vote', params: {'p_candidate_id': candidateId})
          .timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      throw SupportException(e.message);
    }
  }

  Future<List<Charity>> fetchCharities() async {
    final rows = await _client
        .from('charities')
        .select()
        .order('name')
        .timeout(_networkTimeout);
    return rows.map(Charity.fromMap).toList();
  }
}

class SupportException implements Exception {
  const SupportException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single()
        .timeout(_networkTimeout);
    return Profile.fromMap(row);
  }

  Future<void> updateFullName(String userId, String fullName) {
    return _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId)
        .timeout(_networkTimeout);
  }
}

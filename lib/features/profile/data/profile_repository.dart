import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromMap(row);
  }

  Future<void> updateFullName(String userId, String fullName) {
    return _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId);
  }
}

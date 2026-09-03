import 'dart:typed_data';

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

  /// "Nickname" in the UI — the editable display name (public.profiles's
  /// full_name column). Distinct from the permanent, unique username set
  /// at signup.
  Future<void> updateFullName(String userId, String fullName) {
    return _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId)
        .timeout(_networkTimeout);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final result = await _client
        .rpc('is_username_available', params: {'p_username': username})
        .timeout(_networkTimeout);
    return result as bool;
  }

  /// Uploads to the public `avatars` bucket at `<userId>/avatar.<ext>`
  /// (upsert, so re-uploading replaces the old file) and points
  /// profiles.avatar_url at it. Returns the new URL.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$userId/avatar.$fileExtension';
    await _client.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true))
        .timeout(_networkTimeout);

    // Cache-bust: the object path doesn't change on re-upload, so without
    // this a client that already cached the old image would keep showing
    // it after this profile picture changes.
    final url =
        '${_client.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', userId)
        .timeout(_networkTimeout);

    return url;
  }
}

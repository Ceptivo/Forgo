import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/followed_user.dart';
import '../domain/public_profile_stats.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class SocialRepository {
  SocialRepository(this._client);

  final SupabaseClient _client;

  Future<List<FollowedUser>> searchProfiles(String query) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _client
        .rpc('search_profiles', params: {'p_query': query})
        .timeout(_networkTimeout);
    return (rows as List)
        .map(
          (row) => FollowedUser(
            userId: (row as Map<String, dynamic>)['user_id'] as String,
            fullName: row['full_name'] as String,
            username: row['username'] as String?,
            avatarUrl: row['avatar_url'] as String?,
          ),
        )
        .toList();
  }

  Future<List<FollowedUser>> fetchFollowing() async {
    final rows = await _client.rpc('get_following').timeout(_networkTimeout);
    return _parseFollowedUsers(rows);
  }

  /// Who follows [userId] — any profile, not just the caller's own, so
  /// this can back the "Followers" list from any profile screen.
  Future<List<FollowedUser>> fetchFollowers(String userId) async {
    final rows = await _client
        .rpc('get_followers', params: {'p_user_id': userId})
        .timeout(_networkTimeout);
    return _parseFollowedUsers(rows);
  }

  /// Who [userId] follows — any profile, not just the caller's own, so
  /// this can back the "Following" list from any profile screen.
  Future<List<FollowedUser>> fetchFollowees(String userId) async {
    final rows = await _client
        .rpc('get_followees', params: {'p_user_id': userId})
        .timeout(_networkTimeout);
    return _parseFollowedUsers(rows);
  }

  List<FollowedUser> _parseFollowedUsers(Object? rows) {
    return (rows as List)
        .map(
          (row) => FollowedUser(
            userId: (row as Map<String, dynamic>)['user_id'] as String,
            fullName: row['full_name'] as String,
            username: row['username'] as String?,
            avatarUrl: row['avatar_url'] as String?,
          ),
        )
        .toList();
  }

  Future<void> followUser(String userId) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null) throw const SocialException('Not authenticated');
    await _client
        .from('user_follows')
        .insert({'follower_id': callerId, 'followee_id': userId})
        .timeout(_networkTimeout);
  }

  Future<void> unfollowUser(String userId) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null) throw const SocialException('Not authenticated');
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_id', callerId)
        .eq('followee_id', userId)
        .timeout(_networkTimeout);
  }

  Future<PublicProfileStats> fetchPublicProfileStats(String userId) async {
    final rows = (await _client
            .rpc('get_public_profile_stats', params: {'p_user_id': userId})
            .timeout(_networkTimeout))
        as List;
    if (rows.isEmpty) {
      throw const SocialException('User not found');
    }
    return PublicProfileStats.fromMap(userId, rows.first as Map<String, dynamic>);
  }
}

class SocialException implements Exception {
  const SocialException(this.message);

  final String message;

  @override
  String toString() => message;
}

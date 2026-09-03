import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../goals/domain/goal.dart';
import '../domain/goal_group.dart';
import '../domain/goal_group_invite.dart';
import '../domain/goal_group_message.dart';
import '../domain/goal_group_round.dart';
import '../domain/goal_group_stake.dart';

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class GoalGroupRepository {
  GoalGroupRepository(this._client);

  final SupabaseClient _client;

  /// RLS on goal_groups only returns rows the caller is a member of, so
  /// this needs no explicit filter.
  Future<List<GoalGroup>> fetchMyGroups() async {
    final rows = await _client
        .from('goal_groups')
        .select()
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);
    return rows.map(GoalGroup.fromMap).toList();
  }

  Future<GoalGroup> createGroup(String name) async {
    try {
      final result = await _client
          .rpc('create_goal_group', params: {'p_name': name})
          .timeout(_networkTimeout);
      return GoalGroup.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw GoalGroupException(e.message);
    }
  }

  /// A single group's current row — used to keep GroupDetailScreen/
  /// GroupSettingsScreen showing live name/bio/image rather than the
  /// possibly-stale GoalGroup a caller was constructed with.
  Future<GoalGroup> fetchGroup(String groupId) async {
    final row = await _client
        .from('goal_groups')
        .select()
        .eq('id', groupId)
        .single()
        .timeout(_networkTimeout);
    return GoalGroup.fromMap(row);
  }

  Future<GoalGroup> updateGroup({
    required String groupId,
    String? name,
    String? bio,
    String? imageUrl,
  }) async {
    try {
      final result = await _client
          .rpc(
            'update_goal_group',
            params: {
              'p_group_id': groupId,
              'p_name': name,
              'p_bio': bio,
              'p_image_url': imageUrl,
            },
          )
          .timeout(_networkTimeout);
      return GoalGroup.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw GoalGroupException(e.message);
    }
  }

  /// Same folder-per-group + cache-busted pattern as
  /// ProfileRepository.uploadAvatar, just keyed by group id instead of
  /// user id and gated by group membership instead of an exact
  /// auth.uid() match (see the group_images storage policies).
  Future<String> uploadGroupImage({
    required String groupId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$groupId/image.$fileExtension';
    await _client.storage
        .from('group_images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$fileExtension',
          ),
        )
        .timeout(_networkTimeout);

    final url =
        '${_client.storage.from('group_images').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';

    await updateGroup(groupId: groupId, imageUrl: url);
    return url;
  }

  Future<GoalGroup> joinGroupByCode(String inviteCode) async {
    try {
      final result = await _client
          .rpc('join_goal_group_by_code', params: {'p_invite_code': inviteCode})
          .timeout(_networkTimeout);
      return GoalGroup.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      if (e.message.contains('Invalid invite code')) {
        throw const GoalGroupException('That invite code doesn\'t match a group.');
      }
      throw GoalGroupException(e.message);
    }
  }

  Future<List<GoalGroupRound>> fetchRounds(String groupId) async {
    final rows = await _client
        .from('goal_group_goals')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);
    return rows.map(GoalGroupRound.fromMap).toList();
  }

  Future<List<GoalGroupStake>> fetchStakesForRound(String roundId) async {
    final rows = await _client
        .from('goal_group_stakes')
        .select()
        .eq('goal_group_goal_id', roundId)
        .timeout(_networkTimeout);
    return rows.map(GoalGroupStake.fromMap).toList();
  }

  /// Every stake ever taken in the group, across all rounds — the raw
  /// material the leaderboard is aggregated from.
  Future<List<GoalGroupStake>> fetchStakes(String groupId) async {
    final rows = await _client
        .from('goal_group_stakes')
        .select('*, goal_group_goals!inner(group_id)')
        .eq('goal_group_goals.group_id', groupId)
        .timeout(_networkTimeout);
    return rows.map(GoalGroupStake.fromMap).toList();
  }

  /// profiles' RLS only lets a user read their own row, so member display
  /// names come from a scoped RPC instead — see get_goal_group_member_names
  /// in 0005_goal_groups.sql.
  Future<Map<String, String>> fetchMemberNames(String groupId) async {
    final rows = await _client
        .rpc('get_goal_group_member_names', params: {'p_group_id': groupId})
        .timeout(_networkTimeout);
    return {
      for (final row in rows as List)
        (row as Map<String, dynamic>)['user_id'] as String:
            row['full_name'] as String,
    };
  }

  Stream<List<GoalGroupMessage>> watchMessages(String groupId) {
    return _client
        .from('goal_group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at')
        .map((rows) => rows.map(GoalGroupMessage.fromMap).toList());
  }

  Future<void> sendMessage(String groupId, String body) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const GoalGroupException('Not authenticated');
    await _client
        .from('goal_group_messages')
        .insert({
          'group_id': groupId,
          'sender_id': userId,
          'kind': 'text',
          'body': body,
        })
        .timeout(_networkTimeout);
  }

  Future<GoalGroupRound> startRound({
    required String groupId,
    required GoalType type,
    required int stakeCents,
    DateTime? deadline,
    double? distanceKm,
    DistanceCadence? distanceCadence,
    DistanceActivity? distanceActivity,
    double? weightLossTargetKg,
  }) async {
    try {
      final result = await _client
          .rpc(
            'start_goal_group_round',
            params: {
              'p_group_id': groupId,
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
            },
          )
          .timeout(_networkTimeout);
      return GoalGroupRound.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapException(e);
    }
  }

  Future<GoalGroupStake> joinRound(String roundId) async {
    try {
      final result = await _client
          .rpc('join_goal_group_round', params: {'p_round_id': roundId})
          .timeout(_networkTimeout);
      return GoalGroupStake.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapException(e);
    }
  }

  Future<GoalGroupStake> reportOutcome({
    required String roundId,
    required bool completed,
  }) async {
    try {
      final result = await _client
          .rpc(
            'report_goal_group_outcome',
            params: {'p_round_id': roundId, 'p_completed': completed},
          )
          .timeout(_networkTimeout);
      return GoalGroupStake.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapException(e);
    }
  }

  Future<GoalGroupInvite> inviteFriend({
    required String groupId,
    required String friendUserId,
  }) async {
    try {
      final result = await _client
          .rpc(
            'invite_to_goal_group',
            params: {
              'p_group_id': groupId,
              'p_friend_user_id': friendUserId,
            },
          )
          .timeout(_networkTimeout);
      return GoalGroupInvite.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw GoalGroupException(e.message);
    }
  }

  /// Pending invites addressed to the caller, with the group's name
  /// embedded (allowed for a pending invitee even though they aren't a
  /// member yet — see the extra goal_groups SELECT policy in
  /// 0006_social.sql).
  Future<List<GoalGroupInvite>> fetchMyInvites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('goal_group_invites')
        .select('*, goal_groups(name)')
        .eq('invitee_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);
    return rows.map(GoalGroupInvite.fromMap).toList();
  }

  Stream<List<GoalGroupInvite>> watchMyInvites() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(const []);
    return _client
        .from('goal_group_invites')
        .stream(primaryKey: ['id'])
        .eq('invitee_id', userId)
        .order('created_at')
        .map(
          (rows) => rows
              .map(GoalGroupInvite.fromMap)
              .where((invite) => invite.status == GoalGroupInviteStatus.pending)
              .toList(),
        );
  }

  Future<void> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    try {
      await _client
          .rpc(
            'respond_to_goal_group_invite',
            params: {'p_invite_id': inviteId, 'p_accept': accept},
          )
          .timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      throw GoalGroupException(e.message);
    }
  }

  GoalGroupException _mapException(PostgrestException e) {
    if (e.message.contains('Insufficient wallet balance')) {
      return const GoalGroupException(
        'Not enough in your wallet — top up first.',
      );
    }
    return GoalGroupException(e.message);
  }
}

class GoalGroupException implements Exception {
  const GoalGroupException(this.message);

  final String message;

  @override
  String toString() => message;
}

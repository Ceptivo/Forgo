enum GoalGroupInviteStatus { pending, accepted, declined }

/// A pending (or resolved) invite for a followed friend to join a group —
/// created via invite_to_goal_group, resolved via
/// respond_to_goal_group_invite (see 0006_social.sql). Membership is only
/// ever granted once the invitee accepts.
class GoalGroupInvite {
  const GoalGroupInvite({
    required this.id,
    required this.groupId,
    required this.invitedBy,
    required this.inviteeId,
    required this.status,
    required this.createdAt,
    this.groupName,
  });

  factory GoalGroupInvite.fromMap(Map<String, dynamic> map) {
    return GoalGroupInvite(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      invitedBy: map['invited_by'] as String,
      inviteeId: map['invitee_id'] as String,
      status: GoalGroupInviteStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GoalGroupInviteStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      groupName: (map['goal_groups'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  final String id;
  final String groupId;
  final String invitedBy;
  final String inviteeId;
  final GoalGroupInviteStatus status;
  final DateTime createdAt;
  final String? groupName;
}

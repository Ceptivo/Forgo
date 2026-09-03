enum GoalGroupMessageKind { text, systemJoin, systemWin, systemLoss }

GoalGroupMessageKind _kindFromString(String value) => switch (value) {
  'system_join' => GoalGroupMessageKind.systemJoin,
  'system_win' => GoalGroupMessageKind.systemWin,
  'system_loss' => GoalGroupMessageKind.systemLoss,
  _ => GoalGroupMessageKind.text,
};

/// One entry in a group's chat feed — either a plain text message from a
/// member, or a system-generated entry marking a member joining, winning
/// (stake returned), or losing (stake forfeited) a round. Win/loss
/// entries are what make forfeits and payouts "visible" in the group.
class GoalGroupMessage {
  const GoalGroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.amountCents,
    required this.createdAt,
  });

  factory GoalGroupMessage.fromMap(Map<String, dynamic> map) {
    return GoalGroupMessage(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String?,
      kind: _kindFromString(map['kind'] as String),
      body: map['body'] as String,
      amountCents: (map['amount_cents'] as num?)?.toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String? senderId;
  final GoalGroupMessageKind kind;
  final String body;
  final int? amountCents;
  final DateTime createdAt;

  double? get amountRand => amountCents == null ? null : amountCents! / 100;
}

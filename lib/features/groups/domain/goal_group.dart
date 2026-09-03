class GoalGroup {
  const GoalGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.bio,
    this.imageUrl,
  });

  factory GoalGroup.fromMap(Map<String, dynamic> map) {
    return GoalGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      bio: map['bio'] as String?,
      imageUrl: map['image_url'] as String?,
    );
  }

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final String? bio;
  final String? imageUrl;
}

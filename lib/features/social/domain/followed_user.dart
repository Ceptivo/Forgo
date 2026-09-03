class FollowedUser {
  const FollowedUser({
    required this.userId,
    required this.fullName,
    this.username,
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final String? username;
  final String? avatarUrl;
}

/// A user's public-facing profile card — their own, or someone else's.
/// [isFollowing] reflects the *caller's* relationship to this user, so it
/// doesn't mean much when this is the caller's own profile.
class PublicProfileStats {
  const PublicProfileStats({
    required this.userId,
    required this.fullName,
    required this.followerCount,
    required this.followingCount,
    required this.completedGoalsCount,
    required this.isFollowing,
  });

  factory PublicProfileStats.fromMap(String userId, Map<String, dynamic> map) {
    return PublicProfileStats(
      userId: userId,
      fullName: map['full_name'] as String,
      followerCount: (map['follower_count'] as num).toInt(),
      followingCount: (map['following_count'] as num).toInt(),
      completedGoalsCount: (map['completed_goals_count'] as num).toInt(),
      isFollowing: map['is_following'] as bool,
    );
  }

  final String userId;
  final String fullName;
  final int followerCount;
  final int followingCount;
  final int completedGoalsCount;
  final bool isFollowing;
}

class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.username,
    required this.usernameChangedAt,
    required this.avatarUrl,
    required this.dateOfBirth,
    required this.walletBalanceCents,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      usernameChangedAt: map['username_changed_at'] == null
          ? null
          : DateTime.parse(map['username_changed_at'] as String),
      avatarUrl: map['avatar_url'] as String?,
      dateOfBirth: DateTime.parse(map['date_of_birth'] as String),
      walletBalanceCents: (map['wallet_balance_cents'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String username;
  final DateTime? usernameChangedAt;
  final String? avatarUrl;
  final DateTime dateOfBirth;
  final int walletBalanceCents;
  final DateTime createdAt;

  double get walletBalanceRand => walletBalanceCents / 100;
}

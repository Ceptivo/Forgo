import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/social_repository.dart';
import '../domain/followed_user.dart';
import '../domain/public_profile_stats.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

final followingProvider = FutureProvider.autoDispose<List<FollowedUser>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(socialRepositoryProvider).fetchFollowing();
});

final publicProfileStatsProvider = FutureProvider.autoDispose
    .family<PublicProfileStats, String>((ref, userId) {
      return ref.watch(socialRepositoryProvider).fetchPublicProfileStats(userId);
    });

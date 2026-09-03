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

final followersOfProvider = FutureProvider.autoDispose
    .family<List<FollowedUser>, String>((ref, userId) {
      return ref.watch(socialRepositoryProvider).fetchFollowers(userId);
    });

final followingOfProvider = FutureProvider.autoDispose
    .family<List<FollowedUser>, String>((ref, userId) {
      return ref.watch(socialRepositoryProvider).fetchFollowees(userId);
    });

/// Keyed by the (debounced) search text, so watching this from a widget
/// that also watches other providers doesn't restart the search — a
/// plain `FutureBuilder` with the future built inline in `build()`
/// creates a brand-new Future (and flashes back to its loading state)
/// on every unrelated rebuild, which is what made search results flicker
/// and become impossible to tap.
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<FollowedUser>, String>((ref, query) {
      return ref.watch(socialRepositoryProvider).searchProfiles(query);
    });

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/retryable_error.dart';
import '../../application/social_providers.dart';
import '../../domain/followed_user.dart';
import '../widgets/person_row.dart';

enum FollowListMode { followers, following }

/// Every follower, or everyone followed, for a given profile — reached
/// by tapping the Followers/Following count on any profile, own or
/// someone else's.
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.mode});

  final String userId;
  final FollowListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mode == FollowListMode.followers
        ? followersOfProvider(userId)
        : followingOfProvider(userId);
    final peopleAsync = ref.watch(provider);
    final title = mode == FollowListMode.followers ? 'Followers' : 'Following';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: peopleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load this list.',
            onRetry: () => ref.invalidate(provider),
          ),
        ),
        data: (people) {
          if (people.isEmpty) {
            return Center(
              child: Text(
                mode == FollowListMode.followers
                    ? 'No followers yet.'
                    : 'Not following anyone yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              // Followers/following of the *viewed* profile aren't
              // necessarily followed by the caller — that has to be
              // looked up separately rather than assumed from the list
              // itself, so PersonRow's own following state (from
              // whoever the caller follows) is what actually decides
              // the button, not this list's membership.
              return _FollowAwarePersonRow(person: people[index]);
            },
          );
        },
      ),
    );
  }
}

class _FollowAwarePersonRow extends ConsumerWidget {
  const _FollowAwarePersonRow({required this.person});

  final FollowedUser person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final followingIds =
        followingAsync.value?.map((f) => f.userId).toSet() ?? const {};
    return PersonRow(
      person: person,
      following: followingIds.contains(person.userId),
    );
  }
}

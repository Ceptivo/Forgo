import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../../core/widgets/stat_display.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/social_providers.dart';
import '../../domain/public_profile_stats.dart';

/// Another user's public profile — name, follower/following/completed-
/// goals stats, and a Follow/Following button. Reached from a friend
/// search result or a group's member list.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final isSelf = ref.watch(currentUserProvider)?.id == userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load this profile.',
            onRetry: () => ref.invalidate(publicProfileStatsProvider(userId)),
          ),
        ),
        data: (stats) {
          final textTheme = Theme.of(context).textTheme;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stats.fullName.isNotEmpty
                        ? stats.fullName[0].toUpperCase()
                        : '?',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(stats.fullName, style: textTheme.titleLarge),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: 'Followers', value: stats.followerCount),
                    ),
                    Expanded(
                      child: _Stat(label: 'Following', value: stats.followingCount),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Goals completed',
                        value: stats.completedGoalsCount,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isSelf)
                  SizedBox(
                    width: double.infinity,
                    child: _FollowButton(userId: userId, stats: stats),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatNumber(value: '$value', fontSize: 26),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.userId, required this.stats});

  final String userId;
  final PublicProfileStats stats;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool? _optimisticFollowing;
  bool _busy = false;

  Future<void> _toggle(bool currentlyFollowing) async {
    final next = !currentlyFollowing;
    setState(() {
      _optimisticFollowing = next;
      _busy = true;
    });
    try {
      final repo = ref.read(socialRepositoryProvider);
      if (next) {
        await repo.followUser(widget.userId);
      } else {
        await repo.unfollowUser(widget.userId);
      }
      ref.invalidate(publicProfileStatsProvider(widget.userId));
      ref.invalidate(followingProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticFollowing = currentlyFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = _optimisticFollowing ?? widget.stats.isFollowing;
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return following
        ? OutlinedButton(
            onPressed: () => _toggle(true),
            child: const Text('Following'),
          )
        : ElevatedButton(
            onPressed: () => _toggle(false),
            child: const Text('Follow'),
          );
  }
}

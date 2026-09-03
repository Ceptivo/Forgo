import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../profile/presentation/widgets/profile_stat_cards.dart';
import '../../application/social_providers.dart';
import '../../domain/public_profile_stats.dart';

/// Another user's public profile. Deliberately mirrors ProfileScreen's
/// layout section-for-section (avatar, name, follow stats, completed
/// goals, given to charity, badges) so a profile looks the same whoever
/// is looking at it — the only differences are the things that only make
/// sense for your *own* account: no pencil to edit the name, no settings
/// gear, and the Find friends/Log out buttons are replaced by Follow.
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
          return ResponsivePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: stats.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              stats.avatarUrl!,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            stats.fullName.isNotEmpty
                                ? stats.fullName[0].toUpperCase()
                                : '?',
                            style: textTheme.headlineMedium?.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    stats.fullName,
                    style: textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (stats.username != null)
                  Center(
                    child: Text('@${stats.username}', style: textTheme.bodyMedium),
                  ),
                const SizedBox(height: 20),
                FollowStatsRow(userId: userId),
                const SizedBox(height: 12),
                CompletedGoalsCard(userId: userId),
                const SizedBox(height: 12),
                CharityGivenCard(userId: userId),
                const SizedBox(height: 12),
                BadgesSection(userId: userId),
                const SizedBox(height: 12),
                if (!isSelf) _FollowButton(userId: userId, stats: stats),
              ],
            ),
          );
        },
      ),
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
    return SizedBox(
      width: double.infinity,
      child: following
          ? OutlinedButton(
              onPressed: () => _toggle(true),
              child: const Text('Following'),
            )
          : ElevatedButton(
              onPressed: () => _toggle(false),
              child: const Text('Follow'),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/social_providers.dart';
import '../../domain/followed_user.dart';
import '../screens/user_profile_screen.dart';

/// A tappable row for a person — avatar, name, @username, and a
/// Follow/Following toggle. Shared by the friend search results, the
/// "who you follow" list, and the Followers/Following screens, so
/// tapping into any of them looks and behaves the same way everywhere.
class PersonRow extends ConsumerStatefulWidget {
  const PersonRow({super.key, required this.person, required this.following});

  final FollowedUser person;
  final bool following;

  @override
  ConsumerState<PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends ConsumerState<PersonRow> {
  bool? _optimisticFollowing;
  bool _busy = false;

  Future<void> _toggle() async {
    final nowFollowing = !(_optimisticFollowing ?? widget.following);
    setState(() {
      _optimisticFollowing = nowFollowing;
      _busy = true;
    });
    try {
      final repo = ref.read(socialRepositoryProvider);
      if (nowFollowing) {
        await repo.followUser(widget.person.userId);
      } else {
        await repo.unfollowUser(widget.person.userId);
      }
      ref.invalidate(followingProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticFollowing = !nowFollowing);
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
    final following = _optimisticFollowing ?? widget.following;
    final textTheme = Theme.of(context).textTheme;
    final isSelf = ref.watch(currentUserProvider)?.id == widget.person.userId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: widget.person.userId),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.accentDim,
        backgroundImage: widget.person.avatarUrl != null
            ? NetworkImage(widget.person.avatarUrl!)
            : null,
        child: widget.person.avatarUrl != null
            ? null
            : Text(
                widget.person.fullName.isNotEmpty
                    ? widget.person.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.accentDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Text(widget.person.fullName, style: textTheme.titleMedium),
      subtitle: widget.person.username != null
          ? Text('@${widget.person.username}', style: textTheme.bodySmall)
          : null,
      trailing: isSelf
          ? null
          : SizedBox(
              width: 110,
              child: _busy
                  ? const Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : following
                  ? OutlinedButton(
                      onPressed: _toggle,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                      child: const Text('Following'),
                    )
                  : ElevatedButton(
                      onPressed: _toggle,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                      child: const Text('Follow'),
                    ),
            ),
    );
  }
}

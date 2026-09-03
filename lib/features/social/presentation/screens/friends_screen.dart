import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/social_providers.dart';
import '../../domain/followed_user.dart';
import 'user_profile_screen.dart';

/// Search for other users and follow them, or browse who you already
/// follow — the entry point for "add friends to a group chat" later.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search people by name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _query.isEmpty
                  ? const _FollowingList()
                  : _SearchResults(query: _query),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingList extends ConsumerWidget {
  const _FollowingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final textTheme = Theme.of(context).textTheme;

    return followingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryableError(
        message: 'Could not load who you follow.',
        onRetry: () => ref.invalidate(followingProvider),
      ),
      data: (following) {
        if (following.isEmpty) {
          return Center(
            child: Text(
              'Search above to find and follow people.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          itemCount: following.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) =>
              _PersonRow(person: following[index], following: true),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<FollowedUser>>(
      future: ref.read(socialRepositoryProvider).searchProfiles(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not search right now.'));
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return Center(
            child: Text(
              'No one found for "$query".',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final followingAsync = ref.watch(followingProvider);
        final followingIds = followingAsync.value
            ?.map((f) => f.userId)
            .toSet() ?? const {};
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) => _PersonRow(
            person: results[index],
            following: followingIds.contains(results[index].userId),
          ),
        );
      },
    );
  }
}

class _PersonRow extends ConsumerStatefulWidget {
  const _PersonRow({required this.person, required this.following});

  final FollowedUser person;
  final bool following;

  @override
  ConsumerState<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends ConsumerState<_PersonRow> {
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
      trailing: SizedBox(
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

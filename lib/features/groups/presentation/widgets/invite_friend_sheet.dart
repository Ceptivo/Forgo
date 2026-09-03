import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/domain/followed_user.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';

/// Bottom sheet listing the caller's followed friends who aren't already
/// in the group — tapping one sends a pending invite (accept required,
/// see 0006_social.sql) rather than adding them outright.
void showInviteFriendSheet(BuildContext context, String groupId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _InviteFriendSheet(groupId: groupId),
  );
}

class _InviteFriendSheet extends ConsumerWidget {
  const _InviteFriendSheet({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final memberNamesAsync = ref.watch(goalGroupMemberNamesProvider(groupId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite a friend', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'They\'ll need to accept before joining.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: followingAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Could not load your friends.'),
              ),
              data: (following) {
                final memberIds = memberNamesAsync.value?.keys.toSet() ?? const {};
                final candidates = following
                    .where((f) => !memberIds.contains(f.userId))
                    .toList();
                if (candidates.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      following.isEmpty
                          ? 'Follow people first, then invite them here.'
                          : 'Everyone you follow is already in this group.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) => _CandidateRow(
                    groupId: groupId,
                    friend: candidates[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends ConsumerStatefulWidget {
  const _CandidateRow({required this.groupId, required this.friend});

  final String groupId;
  final FollowedUser friend;

  @override
  ConsumerState<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends ConsumerState<_CandidateRow> {
  bool _busy = false;
  bool _sent = false;

  Future<void> _invite() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(goalGroupRepositoryProvider)
          .inviteFriend(groupId: widget.groupId, friendUserId: widget.friend.userId);
      if (mounted) setState(() => _sent = true);
    } on GoalGroupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.accentDim,
        child: Text(
          widget.friend.fullName.isNotEmpty
              ? widget.friend.fullName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppColors.accentDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(widget.friend.fullName),
      trailing: _busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _sent
          ? const Text('Invited', style: TextStyle(color: AppColors.accentDeep, fontWeight: FontWeight.w700))
          : TextButton(onPressed: _invite, child: const Text('Invite')),
    );
  }
}

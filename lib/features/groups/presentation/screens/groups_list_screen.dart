import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../social/application/social_providers.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group_invite.dart';
import '../widgets/create_or_join_group_sheet.dart';
import 'group_detail_screen.dart';
import 'groups_tab.dart';

/// Its own bottom-nav destination — Group Chat Goals, kept separate from
/// the solo Goals tab rather than nested inside it.
class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final group = await showCreateOrJoinGroupSheet(context);
          if (group != null && context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(group: group),
              ),
            );
          }
        },
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('New group'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myGoalGroupsProvider);
          await ref.read(myGoalGroupsProvider.future);
        },
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [_PendingInvites(), GroupsTab()],
          ),
        ),
      ),
    );
  }
}

class _PendingInvites extends ConsumerWidget {
  const _PendingInvites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(myGoalGroupInvitesProvider);
    return invitesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final invite in invites) _InviteCard(invite: invite),
            ],
          ),
        );
      },
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.invite});

  final GoalGroupInvite invite;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(goalGroupRepositoryProvider)
          .respondToInvite(inviteId: widget.invite.id, accept: accept);
      ref.invalidate(myGoalGroupsProvider);
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
    final inviterAsync = ref.watch(
      publicProfileStatsProvider(widget.invite.invitedBy),
    );
    final inviterName = inviterAsync.value?.fullName ?? 'Someone';
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$inviterName invited you to ${widget.invite.groupName ?? 'a group'}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond(true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respond(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

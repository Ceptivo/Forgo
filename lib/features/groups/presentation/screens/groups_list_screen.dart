import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../social/application/social_providers.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group_invite.dart';
import '../widgets/create_or_join_group_sheet.dart';
import 'community_screen.dart';
import 'group_detail_screen.dart';
import 'groups_tab.dart';

enum _GroupsView { mine, community }

/// Its own bottom-nav destination — Group Chat Goals, kept separate from
/// the solo Goals tab rather than nested inside it.
class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  _GroupsView _view = _GroupsView.mine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: DockClearFab(
        child: FloatingActionButton.extended(
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myGoalGroupsProvider);
          await ref.read(myGoalGroupsProvider.future);
        },
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ViewToggleBox(
                      label: 'My Groups',
                      selected: _view == _GroupsView.mine,
                      onTap: () => setState(() => _view = _GroupsView.mine),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ViewToggleBox(
                      label: 'Community',
                      selected: _view == _GroupsView.community,
                      onTap: () =>
                          setState(() => _view = _GroupsView.community),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_view == _GroupsView.mine) ...[
                const _PendingInvites(),
                const GroupsTab(),
              ] else
                const _CommunitySection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewToggleBox extends StatelessWidget {
  const _ViewToggleBox({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// There's no general concept of public/discoverable groups yet — every
/// group today is invite-code-only. Forgo's own community space is the
/// one exception, shown here as a static card rather than something
/// users create.
class _CommunitySection extends StatelessWidget {
  const _CommunitySection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CommunityScreen()),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.accentDim,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.groups_rounded, color: AppColors.accentDeep),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Forgo', style: textTheme.titleMedium),
                    Text('Made for the community', style: textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const PillBadge(label: 'MORE COMING SOON'),
              const SizedBox(height: 12),
              Text('Public groups', style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "Discoverable community groups aren't here yet — for now, "
                'start or join a group with an invite code.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
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

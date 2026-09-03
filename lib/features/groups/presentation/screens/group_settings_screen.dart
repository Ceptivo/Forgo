import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/image_crop_picker.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group.dart';
import '../../domain/goal_group_round.dart';
import 'group_members_screen.dart';

/// Replaces what used to be a single "copy invite code" tap on the (i)
/// icon: a group's image, name, and bio (any member can edit — same
/// trust level as sending a message), its invite code with a dedicated
/// copy button, and every goal round it's ever run.
class GroupSettingsScreen extends ConsumerWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(goalGroupByIdProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load this group.',
            onRetry: () => ref.invalidate(goalGroupByIdProvider(groupId)),
          ),
        ),
        data: (group) => _SettingsBody(group: group),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.group});

  final GoalGroup group;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late final _nameController = TextEditingController(text: widget.group.name);
  late final _bioController = TextEditingController(text: widget.group.bio ?? '');
  bool _saving = false;
  bool _leaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(goalGroupRepositoryProvider)
          .updateGroup(
            groupId: widget.group.id,
            name: name,
            bio: _bioController.text.trim(),
          );
      ref.invalidate(goalGroupByIdProvider(widget.group.id));
      ref.invalidate(myGoalGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group updated.')));
      }
    } on GoalGroupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text("You'll need a new invite to rejoin."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _leaving = true);
    try {
      await ref.read(goalGroupRepositoryProvider).leaveGroup(widget.group.id);
      ref.invalidate(myGoalGroupsProvider);
      if (mounted) {
        // Pops both this settings screen and the group chat behind it —
        // staying in either doesn't make sense once you're no longer a
        // member (RLS will start denying reads for this group anyway).
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pop();
      }
    } on GoalGroupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupImagePicker(group: widget.group),
          const SizedBox(height: 24),
          Text('Name', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _nameController, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 16),
          Text('Bio', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What\'s this group about?'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
          const SizedBox(height: 28),
          Text('Invite code', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.group.inviteCode,
                    style: textTheme.titleLarge?.copyWith(letterSpacing: 2),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  },
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Copy code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Members', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          _MembersRow(groupId: widget.group.id),
          const SizedBox(height: 28),
          Text('Goals', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          _GroupRoundsList(groupId: widget.group.id),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _leaving ? null : _confirmAndLeave,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: _leaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: const Text('Leave group'),
          ),
          const SizedBox(height: DockClearFab.clearance),
        ],
      ),
    );
  }
}

class _GroupImagePicker extends ConsumerStatefulWidget {
  const _GroupImagePicker({required this.group});

  final GoalGroup group;

  @override
  ConsumerState<_GroupImagePicker> createState() => _GroupImagePickerState();
}

class _GroupImagePickerState extends ConsumerState<_GroupImagePicker> {
  bool _uploading = false;

  Future<void> _pick() async {
    final cropped = await pickAndCropCircularImage(context);
    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref
          .read(goalGroupRepositoryProvider)
          .uploadGroupImage(
            groupId: widget.group.id,
            bytes: cropped,
            fileExtension: 'png',
          );
      ref.invalidate(goalGroupByIdProvider(widget.group.id));
      ref.invalidate(myGoalGroupsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the group photo — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.group.imageUrl;
    return Center(
      child: GestureDetector(
        onTap: _uploading ? null : _pick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentDim,
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: _uploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        imageUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.groups_rounded, color: AppColors.accentDeep, size: 32),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersRow extends ConsumerWidget {
  const _MembersRow({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final namesAsync = ref.watch(goalGroupMemberNamesProvider(groupId));
    final count = namesAsync.value?.length;
    final textTheme = Theme.of(context).textTheme;

    return BentoCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupMembersScreen(groupId: groupId)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == null
                  ? 'Loading members…'
                  : '$count ${count == 1 ? 'member' : 'members'}',
              style: textTheme.titleMedium,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _GroupRoundsList extends ConsumerWidget {
  const _GroupRoundsList({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(goalGroupRoundsProvider(groupId));
    final namesAsync = ref.watch(goalGroupMemberNamesProvider(groupId));
    final textTheme = Theme.of(context).textTheme;

    return roundsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Text('Could not load goals.', style: textTheme.bodySmall),
      data: (rounds) {
        if (rounds.isEmpty) {
          return Text(
            'No goals started in this group yet.',
            style: textTheme.bodySmall,
          );
        }
        final memberCount = namesAsync.value?.length ?? 0;
        return Column(
          children: [
            for (final round in rounds)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoundRow(round: round, memberCount: memberCount),
              ),
          ],
        );
      },
    );
  }
}

class _RoundRow extends ConsumerWidget {
  const _RoundRow({required this.round, required this.memberCount});

  final GoalGroupRound round;
  final int memberCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stakesAsync = ref.watch(goalGroupRoundStakesProvider(round.id));
    final textTheme = Theme.of(context).textTheme;
    final joined = stakesAsync.value?.length;

    return BentoCard(
      onTap: () => _showJoinStatus(context, ref),
      child: Row(
        children: [
          Icon(
            round.status == GoalGroupRoundStatus.active
                ? Icons.bolt_rounded
                : Icons.flag_rounded,
            color: AppColors.accentDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(round.title, style: textTheme.titleMedium),
                Text(
                  '${DateFormat.yMMMd().format(round.createdAt)} · '
                  '${round.status == GoalGroupRoundStatus.active ? 'Active' : 'Resolved'}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (joined != null && memberCount > 0)
            PillBadge(label: '$joined/$memberCount'),
        ],
      ),
    );
  }

  void _showJoinStatus(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RoundJoinStatusSheet(round: round),
    );
  }
}

/// Who's joined vs who hasn't — there's no explicit "declined" state
/// tracked anywhere (only a join creates a goal_group_stakes row), so
/// this shows "hasn't joined yet" rather than claiming to know who
/// deliberately said no.
class _RoundJoinStatusSheet extends ConsumerWidget {
  const _RoundJoinStatusSheet({required this.round});

  final GoalGroupRound round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stakesAsync = ref.watch(goalGroupRoundStakesProvider(round.id));
    final namesAsync = ref.watch(goalGroupMemberNamesProvider(round.groupId));
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: (stakesAsync.value == null || namesAsync.value == null)
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Builder(
              builder: (context) {
                final names = namesAsync.value!;
                final joinedIds = stakesAsync.value!.map((s) => s.userId).toSet();
                final joined = joinedIds.toList();
                final notJoined = names.keys.where((id) => !joinedIds.contains(id)).toList();

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(round.title, style: textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      Text('Joined (${joined.length})', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (joined.isEmpty)
                        Text('No one yet.', style: textTheme.bodySmall)
                      else
                        for (final id in joined) _NameRow(name: names[id] ?? 'Member'),
                      const SizedBox(height: 20),
                      Text(
                        "Haven't joined (${notJoined.length})",
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (notJoined.isEmpty)
                        Text('Everyone has joined.', style: textTheme.bodySmall)
                      else
                        for (final id in notJoined) _NameRow(name: names[id] ?? 'Member'),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.accentDim,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(name, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

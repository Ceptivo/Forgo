import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/goal_group_providers.dart';
import '../../domain/goal_group.dart';
import 'group_detail_screen.dart';

/// The "Groups" side of the Goals tab's segmented toggle — a search
/// field plus the caller's groups, or an empty state prompting them to
/// start/join one.
class GroupsTab extends ConsumerStatefulWidget {
  const GroupsTab({super.key});

  @override
  ConsumerState<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<GroupsTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(myGoalGroupsProvider);
    final textTheme = Theme.of(context).textTheme;

    return groupsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RetryableError(
        message: 'Could not load groups.',
        onRetry: () => ref.invalidate(myGoalGroupsProvider),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const PillBadge(label: 'NO GROUPS YET'),
                const SizedBox(height: 12),
                Text('Stake with friends', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Start a group or join one with an invite code.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final query = _query.trim().toLowerCase();
        final filtered = query.isEmpty
            ? groups
            : groups
                  .where((g) => g.name.toLowerCase().contains(query))
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search your groups',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No groups found for "$_query".',
                  style: textTheme.bodyMedium,
                ),
              )
            else
              for (final group in filtered) _GroupCard(group: group),
            const SizedBox(height: 72), // clear of the FAB
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final GoalGroup group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
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
              clipBehavior: Clip.antiAlias,
              child: group.imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        group.imageUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.groups_rounded, color: AppColors.accentDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: textTheme.titleMedium),
                  Text(
                    'Started ${DateFormat.yMMMd().format(group.createdAt)} · Code ${group.inviteCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

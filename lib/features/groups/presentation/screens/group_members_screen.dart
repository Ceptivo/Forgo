import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../social/presentation/screens/user_profile_screen.dart';
import '../../application/goal_group_providers.dart';

/// Every member of a group, searchable by name — tapping one opens
/// their profile.
class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(goalGroupMemberNamesProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search members',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: namesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => RetryableError(
                  message: 'Could not load members.',
                  onRetry: () => ref.invalidate(
                    goalGroupMemberNamesProvider(widget.groupId),
                  ),
                ),
                data: (names) {
                  final entries = names.entries
                      .where(
                        (e) => _query.isEmpty || e.value.toLowerCase().contains(_query),
                      )
                      .toList()
                    ..sort((a, b) => a.value.compareTo(b.value));

                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty ? 'No members.' : 'No one found for "$_query".',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: entry.key),
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentDim,
                          child: Text(
                            entry.value.isNotEmpty ? entry.value[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.accentDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(entry.value),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group.dart';

/// Bottom sheet with two tabs — start a brand new group, or join an
/// existing one by invite code. Returns the resulting [GoalGroup] (so the
/// caller can navigate straight into it) or null if dismissed.
Future<GoalGroup?> showCreateOrJoinGroupSheet(BuildContext context) {
  return showModalBottomSheet<GoalGroup>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CreateOrJoinGroupSheet(),
  );
}

class _CreateOrJoinGroupSheet extends StatefulWidget {
  const _CreateOrJoinGroupSheet();

  @override
  State<_CreateOrJoinGroupSheet> createState() =>
      _CreateOrJoinGroupSheetState();
}

class _CreateOrJoinGroupSheetState extends State<_CreateOrJoinGroupSheet> {
  bool _joining = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _joining ? 'Join a group' : 'Start a group',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _joining
                  ? 'Enter the invite code someone shared with you.'
                  : 'Create a group, then share its invite code so friends '
                        'can join in.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_joining) const _JoinForm() else const _CreateForm(),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _joining = !_joining),
              child: Text(_joining ? 'Start a group instead' : 'Join with a code instead'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm();

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your group a name');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(goalGroupRepositoryProvider)
          .createGroup(name);
      ref.invalidate(myGoalGroupsProvider);
      if (mounted) Navigator.of(context).pop(group);
    } on GoalGroupException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Group name'),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create group'),
        ),
      ],
    );
  }
}

class _JoinForm extends ConsumerStatefulWidget {
  const _JoinForm();

  @override
  ConsumerState<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends ConsumerState<_JoinForm> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter an invite code');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(goalGroupRepositoryProvider)
          .joinGroupByCode(code);
      ref.invalidate(myGoalGroupsProvider);
      if (mounted) Navigator.of(context).pop(group);
    } on GoalGroupException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code'),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join group'),
        ),
      ],
    );
  }
}

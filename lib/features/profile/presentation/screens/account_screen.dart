import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/profile_providers.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile.dart';

final _usernameFormat = RegExp(r'^[a-z0-9_]{3,20}$');
const _cooldown = Duration(days: 30);

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load your account.',
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AccountRow(
                label: 'Username',
                value: '@${profile.username}',
                trailing: TextButton(
                  onPressed: () => _showUsernameChangeDialog(context, ref, profile),
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 12),
              _AccountRow(
                label: 'Date of birth',
                value: DateFormat.yMMMd().format(profile.dateOfBirth),
              ),
              const SizedBox(height: 12),
              _AccountRow(label: 'Email', value: profile.email),
            ],
          );
        },
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: textTheme.titleMedium),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

Future<void> _showUsernameChangeDialog(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final changedAt = profile.usernameChangedAt;
  if (changedAt != null) {
    final elapsed = DateTime.now().difference(changedAt);
    if (elapsed < _cooldown) {
      final remaining = _cooldown - elapsed;
      final days = remaining.inHours >= 24 ? remaining.inDays + 1 : 1;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Username on cooldown'),
          content: Text(
            'You can change your username again in $days ${days == 1 ? 'day' : 'days'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
  }

  final newUsername = await showDialog<String>(
    context: context,
    builder: (context) => _UsernameChangeDialog(currentUsername: profile.username),
  );
  if (newUsername == null) return;

  try {
    await ref.read(profileRepositoryProvider).changeUsername(newUsername);
    ref.invalidate(currentProfileProvider);
  } on ProfileException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _UsernameChangeDialog extends StatefulWidget {
  const _UsernameChangeDialog({required this.currentUsername});

  final String currentUsername;

  @override
  State<_UsernameChangeDialog> createState() => _UsernameChangeDialogState();
}

class _UsernameChangeDialogState extends State<_UsernameChangeDialog> {
  late final _controller = TextEditingController(text: widget.currentUsername);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim().toLowerCase();
    if (!_usernameFormat.hasMatch(value)) {
      setState(() => _error = 'Lowercase letters, numbers, underscores only — 3-20 characters');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            decoration: InputDecoration(labelText: 'Username', prefixText: '@', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can only do this once every 30 days.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

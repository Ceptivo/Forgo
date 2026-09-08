import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/profile_providers.dart';

class StravaScreen extends ConsumerStatefulWidget {
  const StravaScreen({super.key});

  @override
  ConsumerState<StravaScreen> createState() => _StravaScreenState();
}

class _StravaScreenState extends ConsumerState<StravaScreen> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateStravaUsername(
            ref.read(currentProfileProvider).value!.id,
            _controller.text,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    final profile = profileAsync.value;
    if (profile != null && !_initialized) {
      _controller.text = profile.stravaUsername ?? '';
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Strava')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load your profile.',
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/strava_logo.png',
                  width: 40,
                  height: 40,
                  errorBuilder: (_, _, _) => Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.accentDim,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.directions_run_rounded,
                      color: AppColors.accentDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Add your Strava username so friends know where to '
                    'find you. This just stores what you type — Forgo '
                    "doesn't connect to your Strava account.",
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Strava username',
                prefixText: '@',
              ),
              onSubmitted: (_) => _save(),
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
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

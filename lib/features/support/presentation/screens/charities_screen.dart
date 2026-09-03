import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/support_providers.dart';

/// The charities a goal's forfeited stake goes toward — the (i) icon
/// explains how the split actually works.
class CharitiesScreen extends ConsumerWidget {
  const CharitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charitiesAsync = ref.watch(charitiesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charities we support'),
        actions: [
          IconButton(
            tooltip: 'How it works',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showHowItWorks(context),
          ),
        ],
      ),
      body: charitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load charities.',
            onRetry: () => ref.invalidate(charitiesProvider),
          ),
        ),
        data: (charities) {
          if (charities.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No charities added yet.',
                  style: textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: charities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final charity = charities[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.volunteer_activism_rounded,
                      color: AppColors.accentDeep,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(charity.name, style: textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(charity.description, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How it works'),
        content: const Text(
          "Every pledge for a goal that doesn't get completed goes toward "
          'these charities and Forgo:\n\n'
          '80% of the proceeds go to charity\n'
          '20% of the proceeds go to Forgo, to keep this app going',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

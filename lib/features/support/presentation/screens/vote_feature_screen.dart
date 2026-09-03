import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../application/support_providers.dart';
import '../../data/support_repository.dart';
import '../../domain/feature_candidate.dart';

/// A short, developer-picked shortlist of feature ideas — the one with
/// the most votes is what actually gets built next.
class VoteFeatureScreen extends ConsumerWidget {
  const VoteFeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(featureCandidatesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Vote for a feature')),
      body: candidatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: RetryableError(
            message: 'Could not load the shortlist.',
            onRetry: () => ref.invalidate(featureCandidatesProvider),
          ),
        ),
        data: (candidates) {
          if (candidates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No shortlist yet — check back soon.',
                  style: textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _CandidateCard(candidate: candidates[index]),
          );
        },
      ),
    );
  }
}

class _CandidateCard extends ConsumerStatefulWidget {
  const _CandidateCard({required this.candidate});

  final FeatureCandidate candidate;

  @override
  ConsumerState<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends ConsumerState<_CandidateCard> {
  bool _busy = false;

  Future<void> _vote() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .castFeatureVote(widget.candidate.id);
      ref.invalidate(featureCandidatesProvider);
    } on SupportException catch (e) {
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
    final textTheme = Theme.of(context).textTheme;
    final candidate = widget.candidate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: candidate.myVote ? AppColors.accentDim : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: candidate.myVote ? AppColors.accent : AppColors.surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(candidate.title, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(candidate.description, style: textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${candidate.voteCount} ${candidate.voteCount == 1 ? 'vote' : 'votes'}',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (candidate.myVote)
                const Text(
                  'Voted',
                  style: TextStyle(
                    color: AppColors.accentDeep,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                OutlinedButton(
                  onPressed: _vote,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                  child: const Text('Vote'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

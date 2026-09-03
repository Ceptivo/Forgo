import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/support_providers.dart';
import '../../data/support_repository.dart';
import 'vote_feature_screen.dart';

/// Shared form for both "Report a Bug" and "Suggest a Feature" — same
/// shape (a title, a message), just tagged by kind.
class FeedbackFormScreen extends ConsumerStatefulWidget {
  const FeedbackFormScreen({
    super.key,
    required this.kind,
    required this.appBarTitle,
    required this.heading,
    required this.body,
    required this.titleLabel,
    required this.descriptionLabel,
  });

  final String kind;
  final String appBarTitle;
  final String heading;
  final String body;
  final String titleLabel;
  final String descriptionLabel;

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .submitFeedback(
            kind: widget.kind,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
          );
      if (mounted) setState(() => _submitted = true);
    } on SupportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _submitted
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text('Thanks — sent.', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'We read every one of these.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.heading, style: textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(widget.body, style: textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    Text(widget.titleLabel, style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.descriptionLabel, style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: (_canSubmit && !_submitting) ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send'),
                    ),
                    if (widget.kind == 'feature') ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VoteFeatureScreen(),
                          ),
                        ),
                        child: const Text('Vote for a feature'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

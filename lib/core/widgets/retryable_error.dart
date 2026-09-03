import 'package:flutter/material.dart';

/// A centered "couldn't load this" state with a Retry button — the shared
/// fallback for any `AsyncValue.error` case, so a stalled/failed request
/// (e.g. a network timeout) always gives the user an obvious way forward
/// instead of a dead spinner or silent blank screen.
class RetryableError extends StatelessWidget {
  const RetryableError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

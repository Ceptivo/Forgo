import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/streak_repository.dart';
import '../domain/activity_check_in.dart';
import '../domain/streak_summary.dart';

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepository(ref.watch(supabaseClientProvider));
});

final streakSummaryProvider = FutureProvider.autoDispose
    .family<StreakSummary, String>((ref, userId) {
      return ref.watch(streakRepositoryProvider).fetchSummary(userId);
    });

/// Just the current calendar month — the heatmap only ever shows one
/// month at a time, so there's no reason to fetch further back than its
/// first day.
final checkInHistoryProvider = FutureProvider.autoDispose
    .family<List<ActivityCheckIn>, String>((ref, userId) {
      final now = DateTime.now();
      final since = DateTime(now.year, now.month, 1);
      return ref
          .watch(streakRepositoryProvider)
          .fetchHistory(userId: userId, since: since);
    });

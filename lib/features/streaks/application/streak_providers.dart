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

/// Roughly a year of history — enough for the 52-week badge's heatmap to
/// show real progress without fetching an unbounded amount of data.
final checkInHistoryProvider = FutureProvider.autoDispose
    .family<List<ActivityCheckIn>, String>((ref, userId) {
      final since = DateTime.now().subtract(const Duration(days: 371));
      return ref
          .watch(streakRepositoryProvider)
          .fetchHistory(userId: userId, since: since);
    });

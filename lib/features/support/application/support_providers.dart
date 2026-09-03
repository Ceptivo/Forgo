import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/support_repository.dart';
import '../domain/charity.dart';
import '../domain/feature_candidate.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(supabaseClientProvider));
});

final featureCandidatesProvider =
    FutureProvider.autoDispose<List<FeatureCandidate>>((ref) {
      return ref.watch(supportRepositoryProvider).fetchFeatureCandidates();
    });

final charitiesProvider = FutureProvider.autoDispose<List<Charity>>((ref) {
  return ref.watch(supportRepositoryProvider).fetchCharities();
});

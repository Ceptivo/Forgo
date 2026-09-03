import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/onboarding_repository.dart';

/// Overridden in `main.dart` with the real instance — `SharedPreferences`
/// is loaded once before `runApp` so onboarding/auth redirects can be
/// evaluated synchronously on first frame.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(sharedPreferencesProvider));
});

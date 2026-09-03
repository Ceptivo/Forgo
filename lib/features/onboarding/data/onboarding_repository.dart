import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has completed the first-launch onboarding
/// carousel. A [ChangeNotifier] so the router's redirect logic re-evaluates
/// the moment onboarding completes, without polling.
class OnboardingRepository extends ChangeNotifier {
  OnboardingRepository(this._prefs);

  static const _seenKey = 'has_seen_onboarding';

  final SharedPreferences _prefs;

  bool get hasSeenOnboarding => _prefs.getBool(_seenKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_seenKey, true);
    notifyListeners();
  }
}

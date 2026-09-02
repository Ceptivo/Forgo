import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] (Supabase's auth-state stream) into a [Listenable] so
/// `go_router` can re-evaluate its `redirect` callback whenever auth state
/// changes, without polling.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

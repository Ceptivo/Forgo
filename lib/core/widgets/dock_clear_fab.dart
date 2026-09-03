import 'package:flutter/material.dart';

/// Wraps a `floatingActionButton` with enough bottom padding to clear
/// HomeShell's floating nav dock. The phone layout's outer Scaffold uses
/// `extendBody: true` so the dock overlaps each tab's body — without this,
/// a tab's own FAB renders underneath the dock and is effectively
/// invisible/unreachable.
class DockClearFab extends StatelessWidget {
  const DockClearFab({super.key, required this.child});

  final Widget child;

  static const clearance = 88.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: clearance),
      child: child,
    );
  }
}

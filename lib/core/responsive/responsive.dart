import 'package:flutter/material.dart';

/// Breakpoints and helpers for keeping layouts usable across the range of
/// Android phone/tablet sizes Forgo needs to support — small phones,
/// large phones, and foldable/tablet widths.
class Breakpoints {
  Breakpoints._();

  static const double compact = 600; // phones
  static const double medium = 840; // large phones / small tablets
  static const double expanded = 1200; // tablets
}

enum DeviceSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;

  DeviceSize get deviceSize {
    final width = screenWidth;
    if (width >= Breakpoints.medium) return DeviceSize.expanded;
    if (width >= Breakpoints.compact) return DeviceSize.medium;
    return DeviceSize.compact;
  }

  bool get isCompact => deviceSize == DeviceSize.compact;

  /// Horizontal padding that widens gracefully on larger screens instead of
  /// letting content stretch edge-to-edge.
  double get responsiveHorizontalPadding {
    switch (deviceSize) {
      case DeviceSize.compact:
        return 20;
      case DeviceSize.medium:
        return 32;
      case DeviceSize.expanded:
        return 48;
    }
  }

  /// Caps content width on wide screens so text/forms stay readable, while
  /// using the full width on phones.
  double get maxContentWidth {
    switch (deviceSize) {
      case DeviceSize.compact:
        return double.infinity;
      case DeviceSize.medium:
        return 480;
      case DeviceSize.expanded:
        return 560;
    }
  }
}

/// Wraps a screen's content so it stays centered and readable on wide
/// screens while filling the width on phones, with responsive gutters and
/// safe-area handling baked in.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.scrollable = true,
    this.backgroundColor,
  });

  final Widget child;
  final bool scrollable;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.maxContentWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
        ),
        child: child,
      ),
    );

    final body = Align(alignment: Alignment.topCenter, child: content);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: body,
              )
            : body,
      ),
    );
  }
}

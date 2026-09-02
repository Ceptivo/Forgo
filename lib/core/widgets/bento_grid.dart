import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../theme/app_theme.dart';

/// How much of the row a [BentoGridItem] takes, on a 4-column grid: [wide]
/// spans the full width (a hero/summary card), [half] spans two columns
/// (a stat tile, two per row), [tall] also spans two columns but is twice
/// as high (room for a mini chart or a short list).
enum BentoSize { wide, half, tall }

/// A staggered "bento box" grid: cards of different sizes packed together,
/// the look popularized by iOS-widget-style dashboards. Not scrollable
/// itself — place it inside the page's own scroll view.
class BentoGrid extends StatelessWidget {
  const BentoGrid({super.key, required this.items});

  final List<BentoGridItem> items;

  static const _crossAxisCount = 4;

  @override
  Widget build(BuildContext context) {
    return StaggeredGrid.count(
      crossAxisCount: _crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items.map((item) {
        final crossAxisCellCount = switch (item.size) {
          BentoSize.wide => _crossAxisCount,
          BentoSize.half || BentoSize.tall => _crossAxisCount ~/ 2,
        };
        // Cell height is a multiple of a single column's *width* (the
        // staggered grid uses square base units), so a half-width tile
        // needs a taller multiplier than its width alone would suggest to
        // fit icon + a couple of lines of text without overflowing.
        final mainAxisCellCount = switch (item.size) {
          BentoSize.wide => 2.1,
          BentoSize.half => 1.5,
          BentoSize.tall => 3.0,
        };
        return StaggeredGridTile.count(
          crossAxisCellCount: crossAxisCellCount,
          mainAxisCellCount: mainAxisCellCount,
          child: item.child,
        );
      }).toList(),
    );
  }
}

/// One entry in a [BentoGrid].
class BentoGridItem {
  const BentoGridItem({required this.size, required this.child});

  final BentoSize size;
  final Widget child;
}

/// A single bento tile: rounded surface, optional accent gradient, tap
/// target, and full-height fill so it stretches to whatever cell size the
/// grid gives it.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      height: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.accent.withValues(alpha: 0.15),
        highlightColor: AppColors.accent.withValues(alpha: 0.08),
        child: card,
      ),
    );
  }
}

/// A small rounded "pill" badge/chip, e.g. a status label or the "SKIP"
/// button style from the reference screens.
class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.accentBright;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? tint : tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.black : tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.black : tint,
            ),
          ),
        ],
      ),
    );
  }
}

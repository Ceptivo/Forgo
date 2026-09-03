import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A big bold stat number with a small superscript unit/suffix (e.g.
/// "71,74" + "%", or "R" + "250") — the oversized-number-with-small-suffix
/// pattern used throughout the reference dashboard's stat cards.
class StatNumber extends StatelessWidget {
  const StatNumber({
    super.key,
    required this.value,
    this.suffix,
    this.prefix,
    this.fontSize = 34,
    this.color,
  });

  final String value;
  final String? suffix;
  final String? prefix;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w700,
          color: tint,
          fontSize: fontSize,
          height: 1.0,
        ),
        children: [
          if (prefix != null)
            TextSpan(
              text: prefix,
              style: TextStyle(fontSize: fontSize * 0.5),
            ),
          TextSpan(text: value),
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: TextStyle(fontSize: fontSize * 0.4),
            ),
        ],
      ),
    );
  }
}

/// A row of thin vertical ticks with a filled leading portion — the
/// segmented progress indicator under stat cards like "Synced Records" /
/// "Anomalies" in the reference dashboard.
class SegmentedProgressBar extends StatelessWidget {
  const SegmentedProgressBar({
    super.key,
    required this.progress,
    this.segments = 24,
    this.height = 18,
    this.color,
  });

  /// 0.0–1.0.
  final double progress;
  final int segments;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final filledCount = (segments * progress.clamp(0, 1)).round();
    final fillColor = color ?? AppColors.accentDeep;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tickWidth = (constraints.maxWidth / segments).clamp(2.0, 8.0);
          return Row(
            children: [
              for (var i = 0; i < segments; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == segments - 1 ? 0 : tickWidth * 0.5,
                  ),
                  child: Container(
                    width: tickWidth,
                    height: i < filledCount ? height : height * 0.45,
                    decoration: BoxDecoration(
                      color: i < filledCount
                          ? (i == filledCount - 1 ? AppColors.ink : fillColor)
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A semi-circle gauge arc with a dot marker at the progress point — the
/// "Synced Records" style gauge in the reference dashboard.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.progress,
    this.size = 96,
    this.strokeWidth = 8,
    this.color,
  });

  /// 0.0–1.0.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size / 2 + strokeWidth,
      child: CustomPaint(
        painter: _ArcGaugePainter(
          progress: progress.clamp(0, 1),
          strokeWidth: strokeWidth,
          trackColor: AppColors.surfaceMuted,
          fillColor: color ?? AppColors.accentDeep,
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      (size.width - strokeWidth),
    );

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweep = math.pi * progress;
    canvas.drawArc(rect, math.pi, sweep, false, fillPaint);

    // Dot marker at the end of the filled arc.
    final angle = math.pi + sweep;
    final radius = rect.width / 2;
    final center = rect.center;
    final dotCenter = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(dotCenter, strokeWidth * 0.65, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.trackColor != trackColor;
}

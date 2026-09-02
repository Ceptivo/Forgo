import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The faint grid + soft violet glow backdrop used behind hero content,
/// echoing the dark-grid-plus-light-streak look of the reference screens
/// but in black/violet instead of black/amber.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.background),
            child: CustomPaint(painter: _GridPainter()),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: _glowBlob(280, AppColors.accent.withValues(alpha: 0.35)),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _glowBlob(260, AppColors.accentDim.withValues(alpha: 0.45)),
        ),
        child,
      ],
    );
  }

  Widget _glowBlob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const _spacing = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

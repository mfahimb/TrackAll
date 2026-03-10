import 'package:flutter/material.dart';
import 'dart:math' as math;

// =====================================================================
// LOADING INDICATOR  — Elegant segmented spinner
// Usage:  if (isLoading) const LoadingOverlay()
// =====================================================================

class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({super.key});
  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: const Size(36, 36),
        painter: _SegmentPainter(_ctrl.value),
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  final double t;
  static const _segments = 12;
  static const _blue     = Color(0xFF1A73E8);
  static const _light    = Color(0xFFD2E3FC);

  const _SegmentPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height / 2;
    final outer  = size.width / 2;
    final inner  = outer * 0.46;
    final gap    = 0.18; // radians gap between segments
    final step   = 2 * math.pi / _segments;
    final active = (_segments * t).floor(); // which segment is brightest

    for (int i = 0; i < _segments; i++) {
      // How far behind the active segment (tail fades)
      final behind = (_segments + active - i) % _segments;
      final frac   = 1.0 - (behind / (_segments - 1)).clamp(0.0, 1.0);

      // Scale: active seg is largest, tail shrinks
      final scale  = 0.55 + 0.45 * frac;
      final oR     = outer * scale;
      final iR     = inner * scale;

      final color  = Color.lerp(_light, _blue, frac)!;

      final startA = step * i - math.pi / 2 + gap / 2;
      final sweepA = step - gap;

      final path = Path();
      // Outer arc
      path.arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: oR),
        startA, sweepA, true,
      );
      // Inner arc (reverse)
      path.arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: iR),
        startA + sweepA, -sweepA, false,
      );
      path.close();

      canvas.drawPath(path, Paint()
        ..color  = color
        ..style  = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter o) => o.t != t;
}

// ── Full-screen overlay ───────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      const Color(0xFF1A73E8).withValues(alpha: 0.14),
                blurRadius: 20,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: const LoadingIndicator(),
        ),
      ),
    );
  }
}
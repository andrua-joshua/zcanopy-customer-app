import 'package:flutter/material.dart';
import 'dart:math' as math;

class ZLoadingIndicator extends StatefulWidget {
  const ZLoadingIndicator({
    super.key,
    this.size = 64,
    this.color = Colors.blue,
    this.strokeWidth = 6,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  @override
  State<ZLoadingIndicator> createState() => _ZLoadingIndicatorState();
}

class _ZLoadingIndicatorState extends State<ZLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value; // 0 → 1
          // 0.0–0.7: draw the Z. 0.7–1.0: fade it out.
          final drawPhase = (t / 0.7).clamp(0.0, 1.0);
          final fadePhase =
              t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0);

          return Opacity(
            opacity: fadePhase,
            child: CustomPaint(
              painter: _ZPainter(
                progress: drawPhase,
                color: widget.color,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ZPainter extends CustomPainter {
  _ZPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress; // 0..1
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Build a clean “Z” path within the box with padding.
    final pad = strokeWidth / 2 + 2;
    final p0 = Offset(pad, pad);
    final p1 = Offset(size.width - pad, pad);
    final p2 = Offset(pad, size.height - pad);
    final p3 = Offset(size.width - pad, size.height - pad);

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy);

    // Use PathMetrics to reveal only a portion based on progress.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;
    final drawLen = length * progress;

    // Draw the partial path
    final partial = metric.extractPath(0, math.max(0.1, drawLen));
    canvas.drawPath(partial, paint);
  }

  @override
  bool shouldRepaint(covariant _ZPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

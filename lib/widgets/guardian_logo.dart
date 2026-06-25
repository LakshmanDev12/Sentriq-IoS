import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AnimatedGuardianLogo extends StatefulWidget {
  final double size;
  final bool showWordmark;

  const AnimatedGuardianLogo({
    super.key,
    required this.size,
    this.showWordmark = true,
  });

  @override
  State<AnimatedGuardianLogo> createState() => _AnimatedGuardianLogoState();
}

class _AnimatedGuardianLogoState extends State<AnimatedGuardianLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shieldProgress;
  late Animation<double> _routeProgress;
  late Animation<double> _pinScale;
  late Animation<double> _wordmarkAlpha;

  @override
  void initState() {
    super.initState();
    // Total duration around 3-4 seconds based on staggered tween durations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // 1. Shield: tween(1000) - starts at 0
    _shieldProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.linearToEaseOut),
    );

    // 2. Route: tween(1700) - starts if shield > 0.8 (approx 0.24)
    _routeProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.24, 0.75, curve: Curves.fastOutSlowIn),
    );

    // 3. Pin: spring - starts if route > 0.9 (approx 0.7)
    _pinScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.9, curve: Curves.elasticOut),
    );

    // 4. Wordmark: tween(450) - starts if pin > 0.5 (approx 0.8)
    _wordmarkAlpha = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: GuardianPainter(
                shieldProgress: _shieldProgress.value,
                routeProgress: _routeProgress.value,
                pinScale: _pinScale.value,
              ),
            ),
            if (widget.showWordmark) ...[
              const SizedBox(height: 16),
              Opacity(
                opacity: _wordmarkAlpha.value,
                child: Transform.translate(
                  offset: Offset(0, (1.0 - _wordmarkAlpha.value) * 14.0),
                  child: Text(
                    "Sentriq",
                    style: TextStyle(
                      fontSize: widget.size * 0.18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7F77DD),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class GuardianPainter extends CustomPainter {
  final double shieldProgress;
  final double routeProgress;
  final double pinScale;

  GuardianPainter({
    required this.shieldProgress,
    required this.routeProgress,
    required this.pinScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 130.0;

    // 1. Shield Path
    final shieldPath = Path()
      ..moveTo(65.0 * scale, 12.0 * scale)
      ..lineTo(106.0 * scale, 27.0 * scale)
      ..lineTo(106.0 * scale, 80.0 * scale)
      ..cubicTo(106.0 * scale, 101.0 * scale, 89.0 * scale, 114.0 * scale, 65.0 * scale, 121.0 * scale)
      ..cubicTo(41.0 * scale, 114.0 * scale, 24.0 * scale, 101.0 * scale, 24.0 * scale, 80.0 * scale)
      ..lineTo(24.0 * scale, 27.0 * scale)
      ..close();

    final shieldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    shieldPaint.shader = ui.Gradient.linear(
      Offset(24.0 * scale, 12.0 * scale),
      Offset(106.0 * scale, 121.0 * scale),
      [const Color(0xFFC9545F), const Color(0xFF4F80C8)],
    );

    _drawSegmentedPath(canvas, shieldPath, shieldProgress, shieldPaint);

    // 2. Route Path
    if (shieldProgress > 0.5) {
      final routePath = Path()
        ..moveTo(34.0 * scale, 22.0 * scale)
        ..cubicTo(76.0 * scale, 10.0 * scale, 104.0 * scale, 30.0 * scale, 92.0 * scale, 50.0 * scale)
        ..cubicTo(104.0 * scale, 72.0 * scale, 80.0 * scale, 100.0 * scale, 60.0 * scale, 108.0 * scale)
        ..cubicTo(40.0 * scale, 100.0 * scale, 26.0 * scale, 72.0 * scale, 38.0 * scale, 50.0 * scale)
        ..cubicTo(44.0 * scale, 40.0 * scale, 55.0 * scale, 46.0 * scale, 65.0 * scale, 50.0 * scale);

      final routePaint = Paint()
        ..color = const Color(0xFFEF9F27)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * scale
        ..strokeCap = StrokeCap.round;

      _drawSegmentedPath(canvas, routePath, routeProgress, routePaint);

      // Dot Start
      if (routeProgress > 0.05) {
        canvas.drawCircle(Offset(34.0 * scale, 22.0 * scale), 4.0 * scale, Paint()..color = const Color(0xFFFAC775));
      }
      // Waypoint 1
      if (routeProgress > 0.45) {
        canvas.drawCircle(Offset(92.0 * scale, 50.0 * scale), 4.0 * scale, Paint()..color = const Color(0xFFEF9F27));
      }
      // Waypoint 2
      if (routeProgress > 0.8) {
        canvas.drawCircle(Offset(38.0 * scale, 50.0 * scale), 4.0 * scale, Paint()..color = const Color(0xFFBA7517));
      }
    }

    // 3. Pin
    if (pinScale > 0) {
      canvas.save();
      canvas.translate(65.0 * scale, 50.0 * scale);
      
      final double pScale = pinScale * scale;
      final pinPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(8.0 * pScale, 0, 14.0 * pScale, 6.0 * pScale, 14.0 * pScale, 13.0 * pScale)
        ..cubicTo(14.0 * pScale, 23.0 * pScale, 4.0 * pScale, 31.0 * pScale, 0, 34.0 * pScale)
        ..cubicTo(-4.0 * pScale, 31.0 * pScale, -14.0 * pScale, 23.0 * pScale, -14.0 * pScale, 13.0 * pScale)
        ..cubicTo(-14.0 * pScale, 6.0 * pScale, -8.0 * pScale, 0, 0, 0)
        ..close();

      canvas.drawPath(pinPath, Paint()..color = const Color(0xFFD85A30));
      canvas.drawCircle(Offset(0, 13.0 * pScale), 6.5 * pScale, Paint()..color = Colors.white);

      if (pinScale > 0.8) {
        final double checkProgress = (pinScale - 0.8) / 0.2;
        final checkPath = Path()
          ..moveTo(-3.0 * pScale, 13.0 * pScale)
          ..lineTo(-0.5 * pScale, 16.0 * pScale)
          ..lineTo(4.0 * pScale, 9.0 * pScale);

        final checkPaint = Paint()
          ..color = const Color(0xFFD85A30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * pScale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        _drawSegmentedPath(canvas, checkPath, checkProgress, checkPaint);
      }
      canvas.restore();
    }
  }

  void _drawSegmentedPath(Canvas canvas, Path path, double progress, Paint paint) {
    for (final metric in path.computeMetrics()) {
      final Path extractPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(GuardianPainter oldDelegate) {
    return oldDelegate.shieldProgress != shieldProgress ||
        oldDelegate.routeProgress != routeProgress ||
        oldDelegate.pinScale != pinScale;
  }
}

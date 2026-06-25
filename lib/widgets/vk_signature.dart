import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class VkSignature extends StatefulWidget {
  final double size;
  const VkSignature({super.key, required this.size});

  @override
  State<VkSignature> createState() => _VkSignatureState();
}

class _VkSignatureState extends State<VkSignature> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _vProgress;
  late Animation<double> _kLineProgress;
  late Animation<double> _kArmProgress;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // vProgress: tween(1200, delayMillis = 0)
    // 1200 / 2000 = 0.6
    _vProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    );

    // kLineProgress: tween(1200, delayMillis = 200)
    // 200/2000 = 0.1, (200+1200)/2000 = 0.7
    _kLineProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.7, curve: Curves.easeInOut),
    );

    // kArmProgress: tween(1200, delayMillis = 400)
    // 400/2000 = 0.2, (400+1200)/2000 = 0.8
    _kArmProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    );

    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.linearToEaseOut),
      ),
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
        return Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _scale.value > 0.6 ? 1.0 : 0.0,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: SignaturePainter(
                vProgress: _vProgress.value,
                kLineProgress: _kLineProgress.value,
                kArmProgress: _kArmProgress.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SignaturePainter extends CustomPainter {
  final double vProgress;
  final double kLineProgress;
  final double kArmProgress;

  SignaturePainter({
    required this.vProgress,
    required this.kLineProgress,
    required this.kArmProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleFactor = size.width / 150.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * scaleFactor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect rect = Offset.zero & size;
    paint.shader = ui.Gradient.linear(
      Offset(20.0 * scaleFactor, 25.0 * scaleFactor),
      Offset(140.0 * scaleFactor, 130.0 * scaleFactor),
      [const Color(0xFFC9545F), const Color(0xFF4F80C8)],
    );

    // V Letter: points="20,25 50,130 80,25"
    final vPath = Path()
      ..moveTo(20.0 * scaleFactor, 25.0 * scaleFactor)
      ..lineTo(50.0 * scaleFactor, 130.0 * scaleFactor)
      ..lineTo(80.0 * scaleFactor, 25.0 * scaleFactor);
    _drawSegmentedPath(canvas, vPath, vProgress, paint);

    // K Vertical Line: x1="100" y1="25" x2="100" y2="130"
    final kLinePath = Path()
      ..moveTo(100.0 * scaleFactor, 25.0 * scaleFactor)
      ..lineTo(100.0 * scaleFactor, 130.0 * scaleFactor);
    _drawSegmentedPath(canvas, kLinePath, kLineProgress, paint);

    // K Arms: points="140,30 100,75 140,130"
    final kArmsPath = Path()
      ..moveTo(140.0 * scaleFactor, 30.0 * scaleFactor)
      ..lineTo(100.0 * scaleFactor, 75.0 * scaleFactor)
      ..lineTo(140.0 * scaleFactor, 130.0 * scaleFactor);
    _drawSegmentedPath(canvas, kArmsPath, kArmProgress, paint);
  }

  void _drawSegmentedPath(Canvas canvas, Path path, double progress, Paint paint) {
    for (final metric in path.computeMetrics()) {
      final Path extractPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return oldDelegate.vProgress != vProgress ||
        oldDelegate.kLineProgress != kLineProgress ||
        oldDelegate.kArmProgress != kArmProgress;
  }
}

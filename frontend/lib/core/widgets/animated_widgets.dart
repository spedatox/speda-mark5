import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/jarvis_theme.dart';

/// Animated pulsing glow container
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  const PulsingGlow({
    super.key,
    required this.child,
    this.color = JarvisColors.primary,
    this.minOpacity = 0.3,
    this.maxOpacity = 0.8,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Rotating arc loader
class ArcLoader extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const ArcLoader({
    super.key,
    this.size = 40,
    this.color = JarvisColors.primary,
    this.strokeWidth = 2,
  });

  @override
  State<ArcLoader> createState() => _ArcLoaderState();
}

class _ArcLoaderState extends State<ArcLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: ArcLoaderPainter(
            progress: _controller.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class ArcLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  ArcLoaderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw multiple arcs at different rotations
    for (int i = 0; i < 3; i++) {
      final rotation = progress * 2 * math.pi + (i * math.pi / 1.5);
      const sweepAngle = math.pi / 3;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (i * 4)),
        rotation,
        sweepAngle,
        false,
        paint..color = color.withOpacity(1 - (i * 0.3)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArcLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Typing indicator with dots animation (JARVIS style)
class JarvisTypingIndicator extends StatefulWidget {
  final Color color;

  const JarvisTypingIndicator({
    super.key,
    this.color = JarvisColors.primary,
  });

  @override
  State<JarvisTypingIndicator> createState() => _JarvisTypingIndicatorState();
}

class _JarvisTypingIndicatorState extends State<JarvisTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: JarvisColors.surface,
        border: Border.all(color: JarvisColors.panelBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcLoader(size: 20, color: widget.color, strokeWidth: 2),
          const SizedBox(width: 12),
          Text(
            'PROCESSING',
            style: TextStyle(
              color: widget.color,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dots = '.' * ((_controller.value * 3).floor() + 1);
              return SizedBox(
                width: 20,
                child: Text(
                  dots,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Animated data stream effect (background decoration)
class DataStreamBackground extends StatefulWidget {
  final Color color;

  const DataStreamBackground({
    super.key,
    this.color = JarvisColors.primary,
  });

  @override
  State<DataStreamBackground> createState() => _DataStreamBackgroundState();
}

class _DataStreamBackgroundState extends State<DataStreamBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
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
        return CustomPaint(
          size: Size.infinite,
          painter: DataStreamPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class DataStreamPainter extends CustomPainter {
  final double progress;
  final Color color;

  DataStreamPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw flowing vertical lines
    const lineCount = 20;
    for (int i = 0; i < lineCount; i++) {
      final x = (size.width / lineCount) * i;
      final offset = (progress + (i * 0.05)) % 1;
      final startY = size.height * offset - 100;
      final endY = startY + 50 + (i % 3) * 30;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DataStreamPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Circular radar/scanner animation
class RadarScanner extends StatefulWidget {
  final double size;
  final Color color;

  const RadarScanner({
    super.key,
    this.size = 100,
    this.color = JarvisColors.primary,
  });

  @override
  State<RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<RadarScanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: RadarPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw concentric circles
    final circlePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (i / 3), circlePaint);
    }

    // Draw cross lines
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      circlePaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      circlePaint,
    );

    // Draw sweeping line
    final sweepAngle = progress * 2 * math.pi;
    final endPoint = Offset(
      center.dx + radius * math.cos(sweepAngle - math.pi / 2),
      center.dy + radius * math.sin(sweepAngle - math.pi / 2),
    );

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawLine(center, endPoint, sweepPaint..strokeWidth = 2);

    // Draw sweep trail
    final trailPath = Path()..moveTo(center.dx, center.dy);

    for (double angle = sweepAngle - 0.5; angle <= sweepAngle; angle += 0.02) {
      final x = center.dx + radius * math.cos(angle - math.pi / 2);
      final y = center.dy + radius * math.sin(angle - math.pi / 2);
      trailPath.lineTo(x, y);
    }
    trailPath.close();

    final trailPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        colors: [
          color.withOpacity(0),
          color.withOpacity(0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(trailPath, trailPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Animated hexagon background pattern
class HexagonPattern extends StatelessWidget {
  final Color color;

  const HexagonPattern({
    super.key,
    this.color = JarvisColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: HexagonPatternPainter(color: color),
    );
  }
}

class HexagonPatternPainter extends CustomPainter {
  final Color color;

  HexagonPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const hexSize = 40.0;
    const hexWidth = hexSize * 2;
    final hexHeight = hexSize * math.sqrt(3);

    for (double y = -hexHeight;
        y < size.height + hexHeight;
        y += hexHeight * 0.75) {
      final offsetX = ((y / hexHeight).floor() % 2) * (hexWidth * 0.75);
      for (double x = -hexWidth + offsetX;
          x < size.width + hexWidth;
          x += hexWidth * 1.5) {
        _drawHexagon(canvas, Offset(x, y), hexSize, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

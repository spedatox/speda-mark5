import 'package:flutter/material.dart';
import '../theme/jarvis_theme.dart';

/// Corner accent positions
enum CornerPosition { topLeft, topRight, bottomLeft, bottomRight }

/// HUD-style panel with corner accents like Iron Man 2 UI
class HudPanel extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsets padding;
  final double? width;
  final double? height;
  final bool showCorners;
  final bool showScanLine;
  final Color borderColor;
  final List<Widget>? actions;

  const HudPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
    this.showCorners = true,
    this.showScanLine = false,
    this.borderColor = JarvisColors.panelBorder,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: JarvisColors.panelBackground,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Stack(
        children: [
          // Grid pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPatternPainter(),
            ),
          ),

          // Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) _buildHeader(),
              Flexible(
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ],
          ),

          // Corner accents
          if (showCorners) ...[
            const Positioned(
                top: 0,
                left: 0,
                child: HudCorner(position: CornerPosition.topLeft)),
            const Positioned(
                top: 0,
                right: 0,
                child: HudCorner(position: CornerPosition.topRight)),
            const Positioned(
                bottom: 0,
                left: 0,
                child: HudCorner(position: CornerPosition.bottomLeft)),
            const Positioned(
                bottom: 0,
                right: 0,
                child: HudCorner(position: CornerPosition.bottomRight)),
          ],

          // Scan line effect
          if (showScanLine)
            const Positioned.fill(
              child: ScanLineEffect(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: JarvisColors.panelBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            color: JarvisColors.primary,
            margin: const EdgeInsets.only(right: 10),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!.toUpperCase(),
                  style: const TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: JarvisColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Corner accent widget for HUD panels
class HudCorner extends StatelessWidget {
  final CornerPosition position;
  final double size;
  final Color color;

  const HudCorner({
    super.key,
    required this.position,
    this.size = 12,
    this.color = JarvisColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: CornerPainter(position: position, color: color),
    );
  }
}

class CornerPainter extends CustomPainter {
  final CornerPosition position;
  final Color color;

  CornerPainter({required this.position, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    switch (position) {
      case CornerPosition.topLeft:
        path.moveTo(0, size.height);
        path.lineTo(0, 0);
        path.lineTo(size.width, 0);
        break;
      case CornerPosition.topRight:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        break;
      case CornerPosition.bottomLeft:
        path.moveTo(0, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height);
        break;
      case CornerPosition.bottomRight:
        path.moveTo(size.width, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Grid pattern painter for panel backgrounds
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JarvisColors.gridLine.withOpacity(0.3)
      ..strokeWidth = 0.5;

    const spacing = 20.0;

    // Vertical lines
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated scan line effect
class ScanLineEffect extends StatefulWidget {
  const ScanLineEffect({super.key});

  @override
  State<ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<ScanLineEffect>
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
          painter: ScanLinePainter(progress: _controller.value),
        );
      },
    );
  }
}

class ScanLinePainter extends CustomPainter {
  final double progress;

  ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          JarvisColors.primary.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));

    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), paint);
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Glowing text widget
class GlowingText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double glowRadius;

  const GlowingText({
    super.key,
    required this.text,
    this.fontSize = 14,
    this.color = JarvisColors.primary,
    this.fontWeight = FontWeight.w400,
    this.letterSpacing = 1,
    this.glowRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        shadows: [
          Shadow(
            color: color.withOpacity(0.8),
            blurRadius: glowRadius,
          ),
          Shadow(
            color: color.withOpacity(0.4),
            blurRadius: glowRadius * 2,
          ),
        ],
      ),
    );
  }
}

/// HUD-style button with glow effect
class HudButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color color;

  const HudButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isActive = false,
    this.color = JarvisColors.primary,
  });

  @override
  State<HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<HudButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:
                isActive ? widget.color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: isActive ? widget.color : JarvisColors.panelBorder,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: isActive ? widget.color : JarvisColors.textMuted,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: isActive ? widget.color : JarvisColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status indicator dot with glow
class StatusIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const StatusIndicator({
    super.key,
    this.isOnline = true,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? JarvisColors.online : JarvisColors.offline;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Hexagonal icon container
class HexIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final bool isActive;

  const HexIcon({
    super.key,
    required this.icon,
    this.size = 48,
    this.color = JarvisColors.primary,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? color : color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: isActive ? color : color.withOpacity(0.5),
      ),
    );
  }
}

/// Progress arc widget
class ProgressArc extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;
  final double strokeWidth;
  final Widget? child;

  const ProgressArc({
    super.key,
    required this.progress,
    this.size = 60,
    this.color = JarvisColors.primary,
    this.strokeWidth = 3,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressArcPainter(
              progress: progress,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ProgressArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -90.0 * (3.14159 / 180);
    final sweepAngle = 360.0 * progress * (3.14159 / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Data display widget with label
class DataDisplay extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color valueColor;

  const DataDisplay({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = JarvisColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: JarvisColors.textMuted,
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            if (unit != null)
              Text(
                unit!,
                style: TextStyle(
                  color: valueColor.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

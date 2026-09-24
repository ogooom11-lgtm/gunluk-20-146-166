import 'dart:math' as math;

import 'package:flutter/material.dart';

/// حلقة تقدّم متحرّكة.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 110,
    this.stroke = 11,
    this.color,
    this.trackColor,
    this.child,
    this.rounded = true,
    this.startAngle = -math.pi / 2,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final bool rounded;
  final double startAngle;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double v, Widget? _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            color: base,
            trackColor: trackColor ?? base.withAlpha(Theme.of(context).brightness == Brightness.dark ? 46 : 30),
            stroke: stroke,
            rounded: rounded,
            startAngle: startAngle,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.stroke,
    required this.rounded,
    required this.startAngle,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double stroke;
  final bool rounded;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(stroke / 2 + 1);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, startAngle, math.pi * 2, false, track);

    if (value <= 0) return;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = rounded ? StrokeCap.round : StrokeCap.butt
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: <Color>[color.withAlpha(190), color],
        transform: GradientRotation(startAngle),
      ).createShader(rect);
    canvas.drawArc(arcRect, startAngle, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}

/// شعار التطبيق (نفس فكرة الأيقونة) مرسوم داخل الواجهة.
class AppLogomark extends StatelessWidget {
  const AppLogomark({super.key, this.size = 96, this.color, this.showRing = true});

  final double size;
  final Color? color;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.square(size),
      painter: _LogomarkPainter(base, showRing),
    );
  }
}

class _LogomarkPainter extends CustomPainter {
  _LogomarkPainter(this.color, this.showRing);

  final Color color;
  final bool showRing;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset center = Offset(size.width / 2, size.height / 2);

    if (showRing) {
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.085
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: <Color>[color.withAlpha(120), color],
        ).createShader(Offset.zero & size);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: s * 0.40),
        -math.pi * 0.72,
        math.pi * 1.52,
        false,
        ring,
      );
      // نقطة الطرف
      final Offset tip = Offset(
        center.dx + s * 0.40 * math.cos(-math.pi * 0.72 + math.pi * 1.52),
        center.dy + s * 0.40 * math.sin(-math.pi * 0.72 + math.pi * 1.52),
      );
      canvas.drawCircle(tip, s * 0.055, Paint()..color = color.withAlpha(200));
    }

    // علامة الصح
    final Paint check = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path path = Path()
      ..moveTo(center.dx - s * 0.16, center.dy + s * 0.02)
      ..lineTo(center.dx - s * 0.03, center.dy + s * 0.15)
      ..lineTo(center.dx + s * 0.19, center.dy - s * 0.14);
    canvas.drawPath(path, check);
  }

  @override
  bool shouldRepaint(_LogomarkPainter old) => old.color != color || old.showRing != showRing;
}

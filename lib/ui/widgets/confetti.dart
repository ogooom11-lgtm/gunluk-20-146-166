import 'dart:math' as math;

import 'package:flutter/material.dart';

/// احتفال بسيط (جزيئات ملوّنة) عند إتمام كل مهام اليوم.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.play, this.onDone, this.pieces = 60});

  final bool play;
  final VoidCallback? onDone;
  final int pieces;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  List<_Piece> _pieces = <_Piece>[];

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onDone?.call();
      }
    });
    // إن بدأت الرسوم مفعّلة من أول بناء، نطلق الحركة بعد الإطار الأول.
    if (widget.play) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _start();
    }
  }

  void _start() {
    final math.Random rnd = math.Random();
    _pieces = List<_Piece>.generate(widget.pieces, (int i) {
      final double angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 1.5;
      final double speed = 320 + rnd.nextDouble() * 380;
      return _Piece(
        x: 0.5,
        y: 1.0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 6 + rnd.nextDouble() * 8,
        color: _colors[rnd.nextInt(_colors.length)],
        spin: (rnd.nextDouble() - 0.5) * 12,
        square: rnd.nextBool(),
      );
    });
    _controller.forward(from: 0);
  }

  static const List<Color> _colors = <Color>[
    Color(0xFF6C6CF2),
    Color(0xFF2FC8B0),
    Color(0xFFE8A93C),
    Color(0xFFE05B7F),
    Color(0xFF43A047),
    Color(0xFF3E8FD8),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.play && !_controller.isAnimating) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) => CustomPaint(
          painter: _ConfettiPainter(
            pieces: _pieces,
            t: _controller.value,
            size: MediaQuery.of(context).size,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.spin,
    required this.square,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double spin;
  final bool square;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.t, required this.size});

  final List<_Piece> pieces;
  final double t;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (pieces.isEmpty) return;
    final double seconds = t * 2.4;
    for (final _Piece p in pieces) {
      final double gravity = 900;
      final double x = size.width * p.x + p.vx * seconds;
      final double y = size.height * p.y + p.vy * seconds + 0.5 * gravity * seconds * seconds;
      if (y > size.height + 40) continue;
      final double opacity = (1 - t).clamp(0.0, 1.0);
      final Paint paint = Paint()..color = p.color.withAlpha((opacity * 255).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * seconds);
      if (p.square) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.7),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t || old.pieces != pieces;
}

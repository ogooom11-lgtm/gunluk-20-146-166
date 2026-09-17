import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';

/// حالة إدخال الرمز — تُستخدم لتلوين النقاط وتحريكها.
enum PinState { idle, verifying, error, success }

/// صفّ نقاط الرمز: نقطة لكل رقم مكتوب **فقط** — بلا خانات فارغة.
///
/// - لا يُعرف طول كلمة المرور من الشاشة: لا نعرض أي عدد، والنقاط تظهر واحدة
///   تلو الأخرى مع الكتابة.
/// - كل النقاط في **صف واحد** يتحرّك أفقيًا (الأحدث ظاهر دائمًا)، فيعمل مع
///   ٤ خانات أو ٦٤ خانة بنفس الشكل.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.state = PinState.idle,
    this.dotSize = 13,
    this.spacing = 9,
  });

  /// كم رقمًا كُتب حتى الآن (النقاط الظاهرة).
  final int filled;
  final PinState state;
  final double dotSize;
  final double spacing;

  Color _color(BuildContext context) {
    switch (state) {
      case PinState.error:
        return const Color(0xFFE05B5B);
      case PinState.success:
        return const Color(0xFF2FA86A);
      case PinState.verifying:
        return context.palette.seed.withAlpha(200);
      case PinState.idle:
        return context.palette.seed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color(context);
    final bool dim = state == PinState.verifying;

    if (filled == 0) {
      // خط دلالة هادئ فقط — لا يكشف عدد الخانات.
      return Center(
        child: Container(
          width: 74,
          height: 3,
          decoration: BoxDecoration(
            color: color.withAlpha(70),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    return SizedBox(
      height: dotSize + 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          textDirection: TextDirection.ltr,
          children: <Widget>[
            for (int i = 0; i < filled; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                child: AnimatedContainer(
                  key: ValueKey<String>('pin_dot_$i'),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(dim ? 130 : 255),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: color.withAlpha(60), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// زر من لوحة الأرقام: تفاعل ضغط (تصغير + توهّج) واهتزاز خفيف.
class PinKey extends StatefulWidget {
  const PinKey({
    super.key,
    this.label,
    this.icon,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.highlight = false,
    this.tooltip,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool highlight;
  final String? tooltip;

  @override
  State<PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<PinKey> {
  bool _down = false;

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final Color base = context.palette.seed;
    final Color fg = widget.highlight
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface.withAlpha(_active ? 235 : 90);
    Widget content = widget.icon != null
        ? Icon(widget.icon, size: 30, color: fg)
        : Text(
            widget.label ?? '',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
          );

    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }

    return Semantics(
      button: true,
      enabled: _active,
      label: widget.label,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _down ? 0.92 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.highlight ? context.palette.linearGradient : null,
            color: widget.highlight ? null : Theme.of(context).colorScheme.surface.withAlpha(_down ? 210 : 150),
            boxShadow: <BoxShadow>[
              if (_down && _active)
                BoxShadow(color: base.withAlpha(60), blurRadius: 14, spreadRadius: 2)
              else if (!widget.highlight)
                BoxShadow(color: Colors.black.withAlpha(context.isDark ? 40 : 12), blurRadius: 8, blurStyle: BlurStyle.normal),
            ],
            border: Border.all(
              color: widget.highlight ? Colors.transparent : context.palette.seed.withAlpha(context.isDark ? 40 : 26),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _active
                  ? () {
                      HapticFeedback.lightImpact();
                      widget.onTap!.call();
                    }
                  : null,
              onLongPress: widget.enabled && widget.onLongPress != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onLongPress!.call();
                    }
                  : null,
              onTapDown: (_) => setState(() => _down = true),
              onTapUp: (_) => setState(() => _down = false),
              onTapCancel: () => setState(() => _down = false),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// لوحة أرقام مخصّصة (1-9 ثم [تأكيد/فراغ] 0 [حذف]).
///
/// الترتيب من اليسار لليمين دائمًا: ١ في أقصى اليسار حتى مع واجهة عربية.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onConfirm,
    this.onClearAll,
    this.enabled = true,
    this.maxKeySize = 84,
    this.spacing = 12,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onConfirm;
  final VoidCallback? onClearAll;
  final bool enabled;
  final double maxKeySize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    // أكبر حجم ممكن مع بقاء الأزرار داخل عرض الشاشة.
    final double keySize = math.min(
      maxKeySize,
      (MediaQuery.of(context).size.width - 44) / 3,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final List<String> row in const <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
        ])
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                for (final String digit in row)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                    child: SizedBox(
                      width: keySize,
                      height: keySize,
                      child: PinKey(
                        key: ValueKey<String>('pin_key_$digit'),
                        label: digit,
                        enabled: enabled,
                        onTap: () => onDigit(digit),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.ltr,
          children: <Widget>[
            SizedBox(
              width: keySize,
              height: keySize,
              child: onConfirm == null
                  ? const SizedBox.shrink()
                  : PinKey(
                      key: const ValueKey<String>('pin_key_confirm'),
                      icon: Icons.check_rounded,
                      highlight: true,
                      enabled: enabled,
                      tooltip: context.tr('security.confirmPin'),
                      onTap: onConfirm,
                    ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: SizedBox(
                width: keySize,
                height: keySize,
                child: PinKey(
                  key: const ValueKey<String>('pin_key_0'),
                  label: '0',
                  enabled: enabled,
                  onTap: () => onDigit('0'),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: SizedBox(
                width: keySize,
                height: keySize,
                child: PinKey(
                  key: const ValueKey<String>('pin_key_back'),
                  icon: Icons.backspace_outlined,
                  enabled: enabled,
                  tooltip: context.tr('security.clearDigit'),
                  onTap: onBackspace,
                  onLongPress: onClearAll,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// حركة اهتزاز أفقية (للخطأ).
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.child, required this.trigger, this.offset = 12});

  final Widget child;

  /// يتغيّر الرقم لبدء اهتزاز جديد.
  final int trigger;
  final double offset;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
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
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double dx = math.sin(t * math.pi * 5) * widget.offset * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

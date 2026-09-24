import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../app_scope.dart';

/// بطاقة موحّدة الشكل تُستخدم في كل التطبيق.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.gradient,
    this.color,
    this.border,
    this.radius = 20,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? gradient;
  final Color? color;
  final BoxBorder? border;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final double scale = context.st.radiusScale;
    final BorderRadius br = BorderRadius.circular(radius * scale);
    final Widget content = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Theme.of(context).cardTheme.color) : null,
        gradient: gradient,
        borderRadius: br,
        border: border,
        boxShadow: shadow && !context.isDark
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF23304A).withAlpha(16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: padding ?? EdgeInsets.all(context.gap.cardPadding),
      child: child,
    );

    if (onTap == null && onLongPress == null) return content;
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );
  }
}

/// تأثير ضغط ناعم مع اهتزاز خفيف.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              tapHaptic(context);
              widget.onTap!.call();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              tapHaptic(context);
              widget.onLongPress!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// عنوان قسم مع إجراء اختياري.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction, this.icon});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.gap.gap * 0.6),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: context.palette.seed),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                children: <Widget>[
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_left_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// شريحة صغيرة (وسم/حالة).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = true,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? context.palette.seed;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: filled ? base.withAlpha(context.isDark ? 60 : 34) : null,
        border: filled ? null : Border.all(color: base.withAlpha(120)),
        borderRadius: BorderRadius.circular(10 * context.st.radiusScale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 12 : 14, color: base),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: base,
                  fontWeight: FontWeight.w600,
                  fontSize: dense ? 11 : 12,
                ),
          ),
        ],
      ),
    );
  }
}

/// حالة فارغة أنيقة.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final Color color = context.palette.seed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[color.withAlpha(60), color.withAlpha(20)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// بطاقة إحصاء صغيرة.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
    this.caption,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? context.palette.seed;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: base.withAlpha(context.isDark ? 60 : 30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 15, color: base),
                ),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTheme.numeric(context, factor: 1.05, color: base),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(caption!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// اهتزاز خفيف عند التفاعل (حسب الإعدادات).
void tapHaptic(BuildContext context) {
  try {
    if (AppScope.of(context, listen: false).settings.haptics) {
      HapticFeedback.selectionClick();
    }
  } catch (_) {}
}

/// اهتزاز أقوى لإتمام الإنجاز.
void successHaptic(BuildContext context) {
  try {
    if (AppScope.of(context, listen: false).settings.haptics) {
      HapticFeedback.mediumImpact();
    }
  } catch (_) {}
}

/// شريط تقدّم رقيق.
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.value, this.color, this.height = 7, this.background});

  final double value;
  final Color? color;
  final double height;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? context.palette.seed;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: background ?? base.withAlpha(context.isDark ? 40 : 28),
          valueColor: AlwaysStoppedAnimation<Color>(base),
        ),
      ),
    );
  }
}

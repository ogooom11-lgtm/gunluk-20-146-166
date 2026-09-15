import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/stats.dart';
import '../app_scope.dart';

/// أعمدة أسبوعية بسيطة وأنيقة.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.days,
    required this.labels,
    this.color,
    this.height = 130,
    this.onTap,
  });

  final List<DayStat> days;
  final List<String> labels;
  final Color? color;
  final double height;
  final void Function(DateTime day)? onTap;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? context.palette.seed;
    final int maxValue = days.fold<int>(1, (int p, DayStat d) => math.max(p, d.total));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: onTap == null ? null : () => onTap!.call(days[i].day),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (days[i].done > 0)
                        Text(
                          context.numStr(days[i].done),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: base,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            final double maxH = c.maxHeight;
                            final double totalH = maxH * (days[i].total / maxValue);
                            final double doneH = maxH * (days[i].done / maxValue);
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: Duration(milliseconds: 500 + i * 60),
                                curve: Curves.easeOutCubic,
                                builder: (BuildContext context, double t, _) => Container(
                                  width: double.infinity,
                                  height: math.max(totalH * t, days[i].total == 0 ? 4 : 6),
                                  decoration: BoxDecoration(
                                    color: base.withAlpha(38),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: math.max(doneH * t, 0),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: <Color>[base, base.withAlpha(200)],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels.length > i ? labels[i] : '',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// رسم دائري (Donut) لتوزيع الفئات.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 150,
    this.stroke = 20,
    this.center,
  });

  final Map<String, int> values;
  final Map<String, Color> colors;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, Widget? _) => CustomPaint(
          painter: _DonutPainter(values: values, colors: colors, stroke: stroke, progress: t),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.stroke,
    required this.progress,
  });

  final Map<String, int> values;
  final Map<String, Color> colors;
  final double stroke;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final int total = values.values.fold(0, (int a, int b) => a + b);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = colors.values.isEmpty
          ? const Color(0xFFBFC6D6)
          : (colors.values.first).withAlpha(26);
    canvas.drawCircle(center, radius, track);
    if (total == 0) return;

    double start = -math.pi / 2;
    values.forEach((String key, int value) {
      final double sweep = (value / total) * math.pi * 2 * progress;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[key] ?? const Color(0xFF9AA4B8);
      canvas.drawArc(rect, start, sweep - 0.02, false, paint);
      start += sweep;
    });
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.values != values;
}

/// أعمدة أوقات اليوم (٦ مجموعات).
class HourBars extends StatelessWidget {
  const HourBars({super.key, required this.hourCounts, this.color, this.height = 96});

  final Map<int, int> hourCounts;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? context.palette.seed;
    final List<int> buckets = List<int>.filled(6, 0);
    hourCounts.forEach((int hour, int count) => buckets[hour ~/ 4] += count);
    final int maxValue = buckets.fold<int>(1, math.max);
    const List<String> ranges = <String>['12-4', '4-8', '8-12', '12-4', '4-8', '8-12'];
    const List<String> suffixes = <String>['ص', 'ص', 'ص', 'م', 'م', 'م'];
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < buckets.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (buckets[i] / maxValue).clamp(0.04, 1),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: <Color>[base, base.withAlpha(150)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.isArabic ? '${ranges[i]} ${suffixes[i]}' : ranges[i],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// خريطة التزام (مربعات) لعدة أسابيع.
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.days,
    this.color,
    this.cell = 15,
    this.gap = 4,
    this.weeks = 16,
  });

  final List<DayStat> days;
  final Color? color;
  final double cell;
  final double gap;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? context.palette.seed;
    final Map<String, DayStat> map = <String, DayStat>{
      for (final DayStat d in days) Heatmap.keyOf(d.day): d,
    };
    final List<DayStat> visible =
        days.length > weeks * 7 ? days.sublist(days.length - weeks * 7) : days;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size =
            ((constraints.maxWidth - gap * (weeks - 1)) / weeks).clamp(6.0, cell);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final DayStat day in visible) _cell(context, base, size, map[Heatmap.keyOf(day.day)]),
          ],
        );
      },
    );
  }

  static String keyOf(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Widget _cell(BuildContext context, Color base, double size, DayStat? stat) {
    final double rate = stat?.rate ?? 0;
    final Color color = stat == null || stat.total == 0
        ? base.withAlpha(context.isDark ? 26 : 18)
        : base.withAlpha((70 + 185 * rate).clamp(70, 255).round());
    return Tooltip(
      message: stat == null
          ? ''
          : '${context.shortDateStr(stat.day)} • ${context.numStr(stat.done)}/${context.numStr(stat.total)}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(math.max(3, size * 0.28)),
        ),
      ),
    );
  }
}

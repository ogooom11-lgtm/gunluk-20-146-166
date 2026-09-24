import 'package:flutter/material.dart';

import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';

/// تقويم شهري تفاعلي مع مؤشرات لكل يوم.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onSelectDay,
    this.onLongPressDay,
    this.compact = false,
  });

  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime>? onLongPressDay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<int> order = Dates.weekOrder(context.st.weekStart);
    final List<DateTime> grid = Dates.monthGrid(month, context.st.weekStart);
    final double cellHeight = compact ? 44 : 56;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final int weekday in order)
              Expanded(
                child: Center(
                  child: Text(
                    context.weekdayStr(
                      Dates.addDays(DateTime(2024, 1, 1), weekday - 1),
                      short: true,
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: cellHeight * 6,
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (final DateTime day in grid)
                _DayCell(
                  day: day,
                  inMonth: day.month == month.month,
                  selected: Dates.sameDay(day, selectedDay),
                  today: Dates.isToday(day),
                  compact: compact,
                  onTap: () => onSelectDay(day),
                  onLongPress: onLongPressDay == null ? null : () => onLongPressDay!.call(day),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.compact,
    required this.onTap,
    this.onLongPress,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final List<Task> tasks = context.app.tasksOn(day).where((Task t) => !t.skipped).toList();
    final int total = tasks.length;
    final int done = tasks.where((Task t) => t.done).length;
    final bool perfect = total > 0 && done == total;
    final Color base = context.palette.seed;
    final bool isDark = context.isDark;

    final List<Color> dots = <Color>[];
    for (final Task t in tasks) {
      final Color c = context.app.categoryColor(t.categoryId);
      if (!dots.contains(c) && dots.length < 3) dots.add(c);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(compact ? 2 : 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: <Color>[base, base.withAlpha(210)],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  )
                : null,
            color: !selected && today ? base.withAlpha(isDark ? 40 : 22) : null,
            borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
            border: today && !selected
                ? Border.all(color: base.withAlpha(120), width: 1.2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                context.numStr(day.day),
                style: AppTheme.numeric(
                  context,
                  factor: 0.72,
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : inMonth
                          ? null
                          : Theme.of(context).textTheme.bodySmall?.color?.withAlpha(150),
                ),
              ),
              const SizedBox(height: 3),
              if (total > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (final Color c in dots)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white.withAlpha(230) : c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              else
                const SizedBox(height: 5),
              if (perfect)
                Icon(
                  Icons.check_circle_rounded,
                  size: 11,
                  color: selected ? Colors.white : base,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط أسبوعي (٧ أيام) — للتنقل السريع.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final DateTime start = Dates.startOfWeek(selectedDay, context.st.weekStart);
    final Color base = context.palette.seed;
    return Row(
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                final DateTime day = Dates.addDays(start, i);
                final bool selected = Dates.sameDay(day, selectedDay);
                final List<Task> tasks = context.app.tasksOn(day);
                final int done = tasks.where((Task t) => t.done).length;
                return GestureDetector(
                  onTap: () => onSelectDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? base : base.withAlpha(context.isDark ? 26 : 16),
                      borderRadius: BorderRadius.circular(16 * context.st.radiusScale),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          context.weekdayStr(day, short: true),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: selected ? Colors.white.withAlpha(220) : null,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.numStr(day.day),
                          style: AppTheme.numeric(
                            context,
                            factor: 0.85,
                            color: selected ? Colors.white : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tasks.isEmpty
                                ? Colors.transparent
                                : (done == tasks.length ? (selected ? Colors.white : base) : base.withAlpha(90)),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

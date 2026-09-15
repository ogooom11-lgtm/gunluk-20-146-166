import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/models/subtask.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import 'common.dart';
import 'pickers.dart';

/// اختيار أيام الأسبوع.
class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({super.key, required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<int> order = Dates.weekOrder(context.st.weekStart);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int weekday in order)
          Builder(
            builder: (BuildContext context) {
              final bool isSelected = selected.contains(weekday);
              return GestureDetector(
                onTap: () {
                  tapHaptic(context);
                  final Set<int> next = Set<int>.from(selected);
                  if (isSelected) {
                    next.remove(weekday);
                  } else {
                    next.add(weekday);
                  }
                  onChanged(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? context.palette.seed : context.palette.seed.withAlpha(context.isDark ? 30 : 18),
                    borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
                  ),
                  child: Text(
                    context.weekdayStr(Dates.addDays(DateTime(2024, 1, 1), weekday - 1), short: true),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected ? Colors.white : null,
                        ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// اختيار لون.
class ColorSelector extends StatelessWidget {
  const ColorSelector({super.key, required this.value, required this.onChanged, this.colors});

  final int value;
  final ValueChanged<int> onChanged;
  final List<int>? colors;

  @override
  Widget build(BuildContext context) {
    final List<int> list = colors ?? CategoryColors.values;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final int colorValue in list)
          GestureDetector(
            onTap: () {
              tapHaptic(context);
              onChanged(colorValue);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Color(colorValue),
                shape: BoxShape.circle,
                border: value == colorValue
                    ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
                    : null,
              ),
              child: value == colorValue
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// اختيار أيقونة.
class IconSelector extends StatelessWidget {
  const IconSelector({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String key in CategoryIcons.keys)
          GestureDetector(
            onTap: () {
              tapHaptic(context);
              onChanged(key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: value == key
                    ? context.palette.seed
                    : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
                borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
              ),
              child: Icon(
                CategoryIcons.byKey(key),
                size: 20,
                color: value == key ? Colors.white : context.palette.seed,
              ),
            ),
          ),
      ],
    );
  }
}

/// اختيار الأولوية.
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({super.key, required this.value, required this.onChanged});

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final TaskPriority priority in TaskPriority.values)
          Expanded(
            child: GestureDetector(
              onTap: () {
                tapHaptic(context);
                onChanged(priority);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: value == priority ? priority.color : priority.color.withAlpha(context.isDark ? 45 : 24),
                  borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
                ),
                child: Center(
                  child: Text(
                    context.tr(priority.labelKey),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: value == priority ? Colors.white : priority.color,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// اختيار الفئة مع زر إدارة الفئات.
class CategorySelector extends StatelessWidget {
  const CategorySelector({super.key, required this.value, required this.onChanged, this.onManage});

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final List<Category> list = context.app.categories.where((Category c) => !c.archived).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final Category c in list)
          GestureDetector(
            onTap: () {
              tapHaptic(context);
              onChanged(c.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: value == c.id ? Color(c.color) : Color(c.color).withAlpha(context.isDark ? 45 : 22),
                borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(c.icon, size: 16, color: value == c.id ? Colors.white : Color(c.color)),
                  const SizedBox(width: 6),
                  Text(
                    c.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: value == c.id ? Colors.white : Color(c.color),
                        ),
                  ),
                ],
              ),
            ),
          ),
        if (onManage != null)
          GestureDetector(
            onTap: () {
              tapHaptic(context);
              onManage!.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
                border: Border.all(color: context.palette.seed.withAlpha(120)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.settings_rounded, size: 15, color: context.palette.seed),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('category.manage'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.palette.seed),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// اختيار التذكيرات (قبل الموعد بـ).
class LeadTimeSelector extends StatelessWidget {
  const LeadTimeSelector({super.key, required this.values, required this.onChanged});

  final List<int> values;
  final ValueChanged<List<int>> onChanged;

  static const List<int> options = <int>[0, 5, 10, 15, 30, 60, 120, 240, 720, 1440];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int minutes in options)
          Builder(
            builder: (BuildContext context) {
              final bool selected = values.contains(minutes);
              return GestureDetector(
                onTap: () {
                  tapHaptic(context);
                  final List<int> next = List<int>.from(values);
                  if (selected) {
                    next.remove(minutes);
                  } else {
                    next.add(minutes);
                  }
                  next.sort();
                  onChanged(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? context.palette.seed : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
                    borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                  ),
                  child: Text(
                    minutes == 0 ? context.tr('calendar.now') : '${context.numStr(minutes)} د',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: selected ? Colors.white : context.palette.seed,
                        ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// اختيار المزاج (سجل اليوم).
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const List<IconData> icons = <IconData>[
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_very_satisfied_rounded,
  ];

  static const List<Color> colors = <Color>[
    Color(0xFFE05B5B),
    Color(0xFFE08A2E),
    Color(0xFF9AA4B8),
    Color(0xFF3E9E5B),
    Color(0xFF1FA8A0),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (int i = 0; i < icons.length; i++)
          GestureDetector(
            onTap: () {
              tapHaptic(context);
              onChanged(i == value ? -1 : i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: value == i ? colors[i].withAlpha(45) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[i],
                size: value == i ? 34 : 29,
                color: value == i ? colors[i] : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
      ],
    );
  }
}

/// صف أوقات (للتذكيرات المخصصة).
class TimeListEditor extends StatelessWidget {
  const TimeListEditor({super.key, required this.minutes, required this.onChanged});

  final List<int> minutes;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int m in minutes)
          Chip(
            label: Text(context.timeStr(m)),
            onDeleted: () {
              final List<int> next = List<int>.from(minutes)..remove(m);
              onChanged(next);
            },
          ),
        ActionChip(
          avatar: const Icon(Icons.add_alarm_rounded, size: 18),
          label: Text(context.tr('task.addReminder')),
          onPressed: () async {
            final int? result = await showTimeWheelSheet(context, initialMinutes: 20 * 60);
            if (result != null && result >= 0) {
              final List<int> next = List<int>.from(minutes)..add(result);
              next.sort();
              onChanged(next);
            }
          },
        ),
      ],
    );
  }
}

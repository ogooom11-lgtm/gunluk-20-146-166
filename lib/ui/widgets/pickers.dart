import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/dates.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import 'common.dart';

/// عنصر قابل للاختيار داخل الأوراق السفلية.
class ChoiceItem<T> {
  const ChoiceItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.subtitle,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final String? subtitle;
}

/// ورقة اختيار عامة.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceItem<T>> options,
  T? value,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 4, context.gap.screenPadding, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final ChoiceItem<T> item = options[index];
                    final bool selected = item.value == value;
                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      color: selected ? context.palette.seed.withAlpha(context.isDark ? 55 : 28) : null,
                      onTap: () => Navigator.of(context).pop(item.value),
                      child: Row(
                        children: <Widget>[
                          if (item.icon != null) ...<Widget>[
                            Icon(item.icon, color: item.color ?? context.palette.seed, size: 22),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item.label, style: Theme.of(context).textTheme.titleSmall),
                                if (item.subtitle != null)
                                  Text(item.subtitle!, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle_rounded, color: context.palette.seed, size: 22),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// اختيار يوم من تقويم مصغّر.
Future<DateTime?> showDayPickerSheet(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
  bool allowClear = false,
}) {
  return showModalBottomSheet<DateTime?>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return _DayPickerSheet(
        initial: initial ?? Dates.today(),
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
        allowClear: allowClear,
      );
    },
  );
}

class _DayPickerSheet extends StatefulWidget {
  const _DayPickerSheet({
    required this.initial,
    this.firstDate,
    this.lastDate,
    this.title,
    this.allowClear = false,
  });

  final DateTime initial;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? title;
  final bool allowClear;

  @override
  State<_DayPickerSheet> createState() => _DayPickerSheetState();
}

class _DayPickerSheetState extends State<_DayPickerSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime _selected = widget.initial;
  bool _yearMode = false;

  bool _enabled(DateTime day) {
    if (widget.firstDate != null && Dates.diffDays(widget.firstDate!, day) < 0) return false;
    if (widget.lastDate != null && Dates.diffDays(day, widget.lastDate!) < 0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<int> order = Dates.weekOrder(context.st.weekStart);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 4, context.gap.screenPadding, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title ?? context.tr('task.date'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.allowClear)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(context.tr('common.clear')),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => setState(() => _month = Dates.addMonths(_month, -1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _yearMode = !_yearMode),
                    child: Center(
                      child: Text(
                        _yearMode
                            ? context.numStr(_month.year)
                            : '${context.monthStr(_month.month)} ${context.numStr(_month.year)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _month = Dates.addMonths(_month, 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
            if (_yearMode)
              SizedBox(
                height: 200,
                child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 2.1,
                  children: <Widget>[
                    for (int y = _month.year - 6; y <= _month.year + 6; y++)
                      TextButton(
                        onPressed: () => setState(() {
                          _month = DateTime(y, _month.month);
                          _yearMode = false;
                        }),
                        child: Text(context.numStr(y)),
                      ),
                  ],
                ),
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  for (final int weekday in order)
                    Expanded(
                      child: Center(
                        child: Text(
                          context.st.isArabic
                              ? _arabicLetter(weekday)
                              : _englishLetter(weekday),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _MonthGrid(
                month: _month,
                selected: _selected,
                weekStart: context.st.weekStart,
                isEnabled: _enabled,
                onSelect: (DateTime day) => setState(() {
                  _selected = day;
                }),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('common.cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(context.tr('common.save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _arabicLetter(int weekday) =>
      const <String>['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'][weekday - 1];

  String _englishLetter(int weekday) =>
      const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.weekStart,
    required this.onSelect,
    required this.isEnabled,
  });

  final DateTime month;
  final DateTime selected;
  final int weekStart;
  final ValueChanged<DateTime> onSelect;
  final bool Function(DateTime) isEnabled;

  @override
  Widget build(BuildContext context) {
    final List<DateTime> grid = Dates.monthGrid(month, weekStart);
    final Color base = context.palette.seed;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      children: <Widget>[
        for (final DateTime day in grid)
          Builder(
            builder: (BuildContext context) {
              final bool inMonth = day.month == month.month;
              final bool isSelected = Dates.sameDay(day, selected);
              final bool enabled = isEnabled(day);
              return GestureDetector(
                onTap: enabled ? () => onSelect(day) : null,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSelected ? base : null,
                    borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                    border: Dates.isToday(day)
                        ? Border.all(color: base.withAlpha(140), width: 1.4)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      context.numStr(day.day),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: !enabled
                                ? Theme.of(context).disabledColor
                                : isSelected
                                    ? Colors.white
                                    : inMonth
                                        ? null
                                        : Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
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

/// منتقي وقت بعجلات (ساعات/دقائق) مع ص/م.
Future<int?> showTimeWheelSheet(
  BuildContext context, {
  int? initialMinutes,
  String? title,
  bool allowClear = false,
  int minuteStep = 5,
}) {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => _TimeWheelSheet(
      initialMinutes: initialMinutes ?? 9 * 60,
      title: title,
      allowClear: allowClear,
      minuteStep: minuteStep,
      hasValue: initialMinutes != null,
    ),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({
    required this.initialMinutes,
    required this.minuteStep,
    required this.hasValue,
    this.title,
    this.allowClear = false,
  });

  final int initialMinutes;
  final int minuteStep;
  final bool hasValue;
  final String? title;
  final bool allowClear;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _hour = widget.initialMinutes ~/ 60;
  late int _minute = (widget.initialMinutes % 60) - ((widget.initialMinutes % 60) % widget.minuteStep);
  late bool _am = _hour < 12;

  late final FixedExtentScrollController _hourCtrl =
      FixedExtentScrollController(initialItem: (_hour % 12 == 0 ? 12 : _hour % 12) - 1);
  late final FixedExtentScrollController _minuteCtrl =
      FixedExtentScrollController(initialItem: _minute ~/ widget.minuteStep);

  int get _result {
    if (context.st.use24Hour) return _hour * 60 + _minute;
    int h = _hour % 12;
    if (!_am) h += 12;
    return h * 60 + _minute;
  }

  @override
  Widget build(BuildContext context) {
    final List<int> minutes = <int>[
      for (int m = 0; m < 60; m += widget.minuteStep) m,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 4, context.gap.screenPadding, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title ?? context.tr('task.time'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.allowClear && widget.hasValue)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(-1),
                    child: Text(context.tr('common.clear')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _Wheel(
                      controller: _hourCtrl,
                      items: <Widget>[
                        for (int i = 1; i <= 12; i++)
                          Center(
                            child: Text(
                              context.numStr(i),
                              style: AppTheme.numeric(context, factor: 1.25),
                            ),
                          ),
                      ],
                      onSelected: (int index) {
                        final int h12 = index + 1;
                        _hour = context.st.use24Hour
                            ? (_am ? (h12 == 12 ? 0 : h12) : (h12 == 12 ? 12 : h12 + 12))
                            : h12;
                      },
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      controller: _minuteCtrl,
                      items: <Widget>[
                        for (final int m in minutes)
                          Center(
                            child: Text(
                              DateNamesPad.pad(m),
                              style: AppTheme.numeric(context, factor: 1.25),
                            ),
                          ),
                      ],
                      onSelected: (int index) => _minute = minutes[index],
                    ),
                  ),
                  if (!context.st.use24Hour)
                    SizedBox(
                      width: 78,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _AmPm(
                            label: context.isArabic ? 'ص' : 'AM',
                            selected: _am,
                            onTap: () => setState(() => _am = true),
                          ),
                          const SizedBox(height: 10),
                          _AmPm(
                            label: context.isArabic ? 'م' : 'PM',
                            selected: !_am,
                            onTap: () => setState(() => _am = false),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('common.cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_result),
                    child: Text(context.tr('common.save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmPm extends StatelessWidget {
  const _AmPm({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.palette.seed : context.palette.seed.withAlpha(28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? Colors.white : context.palette.seed,
              ),
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.controller, required this.items, required this.onSelected});

  final FixedExtentScrollController controller;
  final List<Widget> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 46,
      perspective: 0.003,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: items.length,
        builder: (BuildContext context, int index) => items[index],
      ),
    );
  }
}

/// صياغة الدقائق بصفرين.
class DateNamesPad {
  DateNamesPad._();
  static String pad(int value) => value < 10 ? '0$value' : '$value';
}

/// تأكيد إجراء (حذف مثلًا).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool danger = true,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? const Color(0xFFE05B5B) : null,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? context.tr('common.confirm')),
        ),
      ],
    ),
  );
  return result ?? false;
}

import 'package:flutter/material.dart';

import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/day_timeline.dart';
import '../widgets/month_calendar.dart';
import '../widgets/pickers.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/task_tile.dart';

enum _CalView { month, week, day }

enum _Filter { all, pending, done }

/// شاشة التقويم: عرض شهري/أسبوعي/يومي مع خط زمني بالساعات.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.selectedDay, required this.onDayChanged});

  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(widget.selectedDay.year, widget.selectedDay.month);
  _CalView _view = _CalView.month;
  _Filter _filter = _Filter.all;

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Dates.sameDay(oldWidget.selectedDay, widget.selectedDay) &&
        (widget.selectedDay.year != _month.year || widget.selectedDay.month != _month.month)) {
      _month = DateTime(widget.selectedDay.year, widget.selectedDay.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<Task> dayTasks = app.tasksOn(widget.selectedDay);
    final List<Task> filtered = dayTasks.where((Task task) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.pending:
          return !task.done && !task.skipped;
        case _Filter.done:
          return task.done;
      }
    }).toList();

    final DateTime monthStart = Dates.startOfMonth(_month);
    final DateTime monthEnd = Dates.endOfMonth(_month);
    final List<Task> monthTasks = app.tasksInRange(monthStart, monthEnd);
    final int monthDone = monthTasks.where((Task t) => t.done).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('calendar.title')),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {
              setState(() => _month = DateTime(Dates.today().year, Dates.today().month));
              widget.onDayChanged(Dates.today());
            },
            icon: const Icon(Icons.today_rounded, size: 18),
            label: Text(context.tr('calendar.goToday')),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 0, context.gap.screenPadding, 130),
        children: <Widget>[
          SegmentedButton<_CalView>(
            segments: <ButtonSegment<_CalView>>[
              ButtonSegment<_CalView>(value: _CalView.month, label: Text(context.tr('calendar.monthView'))),
              ButtonSegment<_CalView>(value: _CalView.week, label: Text(context.tr('calendar.weekView'))),
              ButtonSegment<_CalView>(value: _CalView.day, label: Text(context.tr('calendar.dayView'))),
            ],
            selected: <_CalView>{_view},
            onSelectionChanged: (Set<_CalView> value) => setState(() => _view = value.first),
          ),
          const SizedBox(height: 14),
          if (_view == _CalView.month) ...<Widget>[
            _monthHeader(context),
            const SizedBox(height: 6),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: MonthCalendar(
                month: _month,
                selectedDay: widget.selectedDay,
                onSelectDay: (DateTime day) => widget.onDayChanged(day),
                onLongPressDay: (DateTime day) => showQuickAddSheet(context, day: day),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.tr('calendar.monthStats', <String, String>{
                      'done': context.numStr(monthDone),
                      'total': context.numStr(monthTasks.length),
                    }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(context.tr('calendar.tapToAdd'), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ] else if (_view == _CalView.week) ...<Widget>[
            AppCard(
              padding: const EdgeInsets.all(10),
              child: WeekStrip(
                selectedDay: widget.selectedDay,
                onSelectDay: (DateTime day) => widget.onDayChanged(day),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SectionHeader(
            title: _view == _CalView.day ? context.tr('calendar.hours') : context.tr('calendar.agenda'),
            subtitle: context.dateStr(widget.selectedDay),
            icon: Icons.event_note_rounded,
            actionLabel: context.tr('common.add'),
            onAction: () => showQuickAddSheet(context, day: widget.selectedDay),
          ),
          if (_view != _CalView.day) ...<Widget>[
            Row(
              children: <Widget>[
                for (final _Filter filter in _Filter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(context, filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              AppCard(
                child: Column(
                  children: <Widget>[
                    Icon(Icons.event_busy_rounded, size: 30, color: context.palette.seed),
                    const SizedBox(height: 10),
                    Text(context.tr('calendar.empty'), style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => showQuickAddSheet(context, day: widget.selectedDay),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(context.tr('calendar.addHere')),
                    ),
                  ],
                ),
              )
            else
              for (final Task task in filtered) ...<Widget>[
                TaskTile(task: task, dense: false),
                const SizedBox(height: 10),
              ],
          ],
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: DayTimeline(
              key: ValueKey<String>('timeline_${Dates.key(widget.selectedDay)}'),
              day: widget.selectedDay,
              tasks: dayTasks,
              onTapEmptyHour: (int hour) => showQuickAddSheet(
                context,
                day: Dates.at(widget.selectedDay, hour * 60),
                fullEditor: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(BuildContext context, _Filter filter) {
    switch (filter) {
      case _Filter.all:
        return context.tr('calendar.filterAll');
      case _Filter.pending:
        return context.tr('calendar.filterPending');
      case _Filter.done:
        return context.tr('calendar.filterDone');
    }
  }

  Widget _monthHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => setState(() => _month = Dates.addMonths(_month, -1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _pickMonthYear,
            child: Column(
              children: <Widget>[
                Text(
                  '${context.monthStr(_month.month)} ${context.numStr(_month.year)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _month = Dates.addMonths(_month, 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ],
    );
  }

  Future<void> _pickMonthYear() async {
    final DateTime? picked = await showDayPickerSheet(context, initial: widget.selectedDay);
    if (!mounted || picked == null) return;
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
      widget.onDayChanged(picked);
    }
  }
}

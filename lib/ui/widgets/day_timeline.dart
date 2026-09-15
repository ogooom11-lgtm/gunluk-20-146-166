import 'package:flutter/material.dart';

import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../screens/task_details_sheet.dart';

/// خط زمني بالساعات لليوم مع مهام موزّعة حسب وقتها.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.tasks,
    this.startHour = 6,
    this.endHour = 23,
    this.onTapEmptyHour,
  });

  final DateTime day;
  final List<Task> tasks;
  final int startHour;
  final int endHour;
  final void Function(int hour)? onTapEmptyHour;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const double _rowHeight = 66;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  void _scrollToNow() {
    if (!mounted || !_controller.hasClients) return;
    final int nowMinutes = Dates.nowMinutes();
    final double offset =
        ((nowMinutes - widget.startHour * 60) / 60) * _rowHeight - 140;
    _controller.jumpTo(offset.clamp(0, _controller.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int hours = widget.endHour - widget.startHour;
    final double totalHeight = hours * _rowHeight;
    final List<Task> timed = widget.tasks.where((Task t) => t.hasTime).toList();
    final List<Task> untimed = widget.tasks.where((Task t) => !t.hasTime).toList();
    final Color base = context.palette.seed;
    final bool isToday = Dates.isToday(widget.day);
    final int nowMinutes = Dates.nowMinutes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (untimed.isNotEmpty) ...<Widget>[
          Text(
            context.tr('calendar.noTime'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Task task in untimed)
                ActionChip(
                  avatar: CircleAvatar(
                    radius: 9,
                    backgroundColor: context.app.categoryColor(task.categoryId),
                  ),
                  label: Text(
                    task.title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  onPressed: () => showTaskDetailsSheet(context, task.id),
                  backgroundColor: context.app.categoryColor(task.categoryId).withAlpha(26),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(
          context.tr('calendar.hours'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Container(
          height: 430,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20 * context.st.radiusScale),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20 * context.st.radiusScale),
            child: SingleChildScrollView(
              controller: _controller,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: totalHeight,
                child: Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        for (int i = 0; i < hours; i++)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onTapEmptyHour == null
                                ? null
                                : () => widget.onTapEmptyHour!(widget.startHour + i),
                            child: SizedBox(
                              height: _rowHeight,
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: 62,
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(start: 10),
                                      child: Text(
                                        context.hourStr(widget.startHour + i),
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment: AlignmentDirectional.topEnd,
                                      child: Container(
                                        height: 1,
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final Task task in timed)
                      _timedBlock(context, task, totalHeight, base),
                    if (isToday &&
                        nowMinutes >= widget.startHour * 60 &&
                        nowMinutes <= widget.endHour * 60)
                      PositionedDirectional(
                        top: ((nowMinutes - widget.startHour * 60) / 60) * _rowHeight,
                        start: 54,
                        end: 0,
                        child: IgnorePointer(
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1.6,
                                  color: base.withAlpha(200),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timedBlock(BuildContext context, Task task, double totalHeight, Color base) {
    final int start = task.startMinutes!;
    final int duration = task.durationMinutes > 0 ? task.durationMinutes : 45;
    final double top = ((start - widget.startHour * 60) / 60) * _rowHeight;
    final double height = (duration / 60) * _rowHeight;
    if (top + height < 0 || top > totalHeight) return const SizedBox.shrink();

    final Color color = context.app.categoryColor(task.categoryId);
    return PositionedDirectional(
      top: top.clamp(0, totalHeight - 16),
      start: 66,
      end: 8,
      height: height.clamp(34, 400),
      child: GestureDetector(
        onTap: () => showTaskDetailsSheet(context, task.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[color.withAlpha(context.isDark ? 90 : 40), color.withAlpha(context.isDark ? 45 : 20)],
            ),
            borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
            border: BorderDirectional(
              start: BorderSide(color: color, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
              ),
              if (height > 46)
                Text(
                  '${context.timeStr(start)} • ${context.durStr(duration)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../screens/task_details_sheet.dart';
import 'amount_sheet.dart';
import '../screens/task_editor_screen.dart';
import 'common.dart';

/// نصّ كمّية بلا أصفار زائدة (٦٠ لا ٦٠٫٠).
String _amountText(BuildContext context, double value) {
  final String text =
      value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
  return context.numStr(text);
}

/// صف مهمة: تحديد الإنجاز، التفاصيل، والإجراءات السريعة.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.showDate = false,
    this.dense = false,
    this.showPlan = true,
    this.onToggle,
    this.enableSwipe = true,
  });

  final Task task;
  final bool showDate;
  final bool dense;
  final bool showPlan;
  final VoidCallback? onToggle;
  final bool enableSwipe;

  @override
  Widget build(BuildContext context) {
    final Widget tile = _content(context);
    if (!enableSwipe) return tile;
    return Dismissible(
      key: ValueKey<String>('tile_${task.id}'),
      background: _swipeBackground(context, alignEnd: false),
      secondaryBackground: _swipeBackground(context, alignEnd: true),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          _toggle(context);
        } else {
          await context.appRead.moveTaskToTomorrow(task.id);
          if (context.mounted) {
            _snack(context, context.tr('toast.taskMoved'));
          }
        }
        return false;
      },
      child: tile,
    );
  }

  void _toggle(BuildContext context) {
    successHaptic(context);
    if (onToggle != null) {
      onToggle!.call();
    } else {
      context.appRead.toggleTaskDone(task.id);
    }
    if (!task.done) {
      _snack(context, context.tr('task.doneToast'));
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Widget _swipeBackground(BuildContext context, {required bool alignEnd}) {
    final Color color = alignEnd ? const Color(0xFF3E8FD8) : context.palette.seed;
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 8 : 10),
      padding: EdgeInsets.symmetric(horizontal: context.gap.cardPadding),
      alignment: alignEnd ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(18 * context.st.radiusScale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            alignEnd ? Icons.event_repeat_rounded : Icons.check_circle_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            alignEnd ? context.tr('task.moveTomorrow') : context.tr('task.markDone'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final Color catColor = context.app.categoryColor(task.categoryId);
    final ItemState state = task.state;
    final bool isDone = task.done;
    final bool isSkipped = task.skipped;
    final TextStyle? titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          decoration: isDone ? TextDecoration.lineThrough : null,
          color: isDone
              ? Theme.of(context).textTheme.bodySmall?.color
              : isSkipped
                  ? Theme.of(context).textTheme.bodySmall?.color
                  : null,
        );

    return AppCard(
      onTap: () => showTaskDetailsSheet(context, task.id),
      onLongPress: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(taskId: task.id)),
      ),
      shadow: !dense,
      padding: EdgeInsets.symmetric(horizontal: context.gap.cardPadding, vertical: dense ? 10 : 12),
      color: isDone ? context.palette.seed.withAlpha(context.isDark ? 22 : 12) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CheckButton(
            done: isDone,
            skipped: isSkipped,
            color: catColor,
            onTap: () => _toggle(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(task.title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _meta(context, Icons.circle, context.app.categoryName(task.categoryId), catColor, dense: true),
                    if (task.hasTime)
                      _meta(
                        context,
                        Icons.schedule_rounded,
                        task.durationMinutes > 0
                            ? '${context.timeStr(task.startMinutes!)} • ${context.durStr(task.durationMinutes)}'
                            : context.timeStr(task.startMinutes!),
                        context.palette.seed,
                        dense: true,
                      ),
                    if (task.priority == TaskPriority.high || task.priority == TaskPriority.urgent)
                      _meta(context, Icons.flag_rounded, context.tr(task.priority.labelKey), task.priority.color, dense: true),
                    if (task.subtasks.isNotEmpty)
                      _meta(
                        context,
                        Icons.checklist_rounded,
                        '${context.numStr(task.subtaskDone)}/${context.numStr(task.subtasks.length)}',
                        context.palette.seed,
                        dense: true,
                      ),
                    if (showPlan && task.fromPlan)
                      _meta(context, Icons.repeat_rounded, context.tr('plan.title'), const Color(0xFF9C4DCC), dense: true),
                    if (task.hasAmount)
                      _meta(
                        context,
                        Icons.auto_graph_rounded,
                        context.tr('quant.ofPair', <String, String>{
                          'done': _amountText(context, task.amountDone ?? 0),
                          'total': _amountText(context, task.amountTarget ?? 0),
                          'unit': task.amountUnit,
                        }).trim(),
                        const Color(0xFF2FA86A),
                        dense: true,
                      ),
                    if (state == ItemState.missed)
                      _meta(context, Icons.error_outline_rounded, context.tr('task.overdue'), const Color(0xFFE05B5B), dense: true),
                    if (isSkipped)
                      _meta(context, Icons.skip_next_rounded, context.tr('task.stateSkipped'), Colors.blueGrey, dense: true),
                    if (showDate)
                      _meta(context, Icons.event_rounded, context.relativeDay(task.date), Colors.blueGrey, dense: true),
                  ],
                ),
                if (!dense && task.subtasks.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ThinProgress(value: task.progress, color: catColor, height: 5),
                ],
                if (!dense && task.hasAmount) ...<Widget>[
                  const SizedBox(height: 8),
                  AmountBar(
                    done: task.amountDone ?? 0,
                    target: task.amountTarget ?? 0,
                    unit: task.amountUnit,
                    color: catColor,
                    height: 5,
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: <Widget>[
              if (task.hasAmount && !isDone)
                IconButton(
                  key: ValueKey<String>('tile_amount_${task.id}'),
                  onPressed: () => showPlanAmountSheet(
                    context,
                    planId: task.planId ?? '',
                    day: task.date,
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  tooltip: context.tr('quant.log'),
                  visualDensity: VisualDensity.compact,
                ),
              _menu(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String label, Color color, {bool dense = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon == Icons.circle)
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        else
          Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: dense ? 11.5 : 12.5,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      padding: EdgeInsets.zero,
      tooltip: '',
      onSelected: (String value) async {
        switch (value) {
          case 'edit':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(taskId: task.id)),
            );
          case 'done':
            await context.appRead.setTaskDone(task.id, !task.done);
          case 'skip':
            await context.appRead.skipTask(task.id, !task.skipped);
          case 'tomorrow':
            await context.appRead.moveTaskToTomorrow(task.id);
            if (context.mounted) _snack(context, context.tr('toast.taskMoved'));
          case 'amount':
            await showPlanAmountSheet(
              context,
              planId: task.planId ?? '',
              day: task.date,
            );
          case 'snooze':
            await context.appRead.snoozeTask(task.id);
            if (context.mounted) {
              _snack(context, context.tr('toast.snoozed', <String, String>{
                'n': context.numStr(context.st.snoozeMinutes),
              }));
            }
          case 'duplicate':
            await context.appRead.duplicateTask(task.id);
          case 'delete':
            await context.appRead.deleteTask(task.id);
            if (context.mounted) _snack(context, context.tr('task.deleted'));
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'done', child: _menuItem(context, task.done ? 'task.markUndone' : 'task.markDone', Icons.check_circle_outline_rounded)),
        PopupMenuItem<String>(value: 'edit', child: _menuItem(context, 'common.edit', Icons.edit_rounded)),
        if (task.hasAmount)
          PopupMenuItem<String>(
            value: 'amount',
            child: _menuItem(context, 'quant.log', Icons.auto_graph_rounded),
          ),
        PopupMenuItem<String>(value: 'snooze', child: _menuItem(context, 'task.snooze', Icons.snooze_rounded)),
        PopupMenuItem<String>(value: 'tomorrow', child: _menuItem(context, 'task.moveTomorrow', Icons.event_repeat_rounded)),
        PopupMenuItem<String>(value: 'duplicate', child: _menuItem(context, 'task.duplicate', Icons.copy_all_rounded)),
        PopupMenuItem<String>(value: 'skip', child: _menuItem(context, task.skipped ? 'task.unskip' : 'task.markSkip', Icons.skip_next_rounded)),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'delete', child: _menuItem(context, 'common.delete', Icons.delete_outline_rounded, danger: true)),
      ],
    );
  }

  Widget _menuItem(BuildContext context, String key, IconData icon, {bool danger = false}) {
    final Color color = danger ? const Color(0xFFE05B5B) : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(context.tr(key), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
      ],
    );
  }
}

/// زر دائري لتحديد الإنجاز مع حركة أنيقة.
class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.skipped, required this.color, required this.onTap});

  final bool done;
  final bool skipped;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: done
              ? LinearGradient(colors: <Color>[color, color.withAlpha(200)])
              : null,
          color: done ? null : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: done ? Colors.transparent : color.withAlpha(skipped ? 90 : 170),
            width: 2,
          ),
        ),
        child: AnimatedScale(
          scale: done ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: const Icon(Icons.check_rounded, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

/// بطاقة مهمة مصغّرة (لعرضها في الأفقيات).
class TaskMiniCard extends StatelessWidget {
  const TaskMiniCard({super.key, required this.task, this.width = 210});

  final Task task;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Color color = context.app.categoryColor(task.categoryId);
    return SizedBox(
      width: width,
      child: AppCard(
        onTap: () => showTaskDetailsSheet(context, task.id),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.app.categoryName(task.categoryId),
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.hasTime)
                  Text(
                    context.timeStr(task.startMinutes!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.seed),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(child: ThinProgress(value: task.progress, color: color, height: 5)),
                const SizedBox(width: 8),
                Text(
                  Dates.isToday(task.date) ? context.tr('common.today') : context.weekdayStr(task.date, short: true),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

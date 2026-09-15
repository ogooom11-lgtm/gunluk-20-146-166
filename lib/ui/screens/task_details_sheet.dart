import 'package:flutter/material.dart';

import '../../core/models/plan.dart';
import '../../core/models/subtask.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'focus_screen.dart';
import 'plan_details_screen.dart';
import 'task_editor_screen.dart';

/// ورقة تفاصيل الإنجاز: الخطوات، الملاحظات، والإجراءات السريعة.
Future<void> showTaskDetailsSheet(BuildContext context, String taskId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => TaskDetailsSheet(taskId: taskId),
  );
}

class TaskDetailsSheet extends StatelessWidget {
  const TaskDetailsSheet({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final Task? task = context.app.taskById(taskId);
    if (task == null) {
      return const SizedBox(height: 200);
    }
    final Color catColor = context.app.categoryColor(task.categoryId);
    final Plan? plan = task.planId == null ? null : context.app.planById(task.planId!);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 0, context.gap.screenPadding, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(context.isDark ? 60 : 30),
                    borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
                  ),
                  child: Icon(context.app.categoryIcon(task.categoryId), color: catColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          decoration: task.done ? TextDecoration.lineThrough : null,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Pill(
                  label: context.app.categoryName(task.categoryId),
                  color: catColor,
                  icon: Icons.circle,
                ),
                Pill(
                  label: context.tr(task.priority.labelKey),
                  color: task.priority.color,
                  icon: Icons.flag_rounded,
                ),
                Pill(
                  label: context.dateStr(task.date),
                  color: context.palette.seed,
                  icon: Icons.event_rounded,
                ),
                if (task.hasTime)
                  Pill(
                    label: task.durationMinutes > 0
                        ? '${context.timeStr(task.startMinutes!)} • ${context.durStr(task.durationMinutes)}'
                        : context.timeStr(task.startMinutes!),
                    color: const Color(0xFF3E8FD8),
                    icon: Icons.schedule_rounded,
                  ),
                if (task.reminderMinutes().isNotEmpty)
                  Pill(
                    label: '${context.numStr(task.reminderMinutes().length)} ${context.tr('task.reminders')}',
                    color: const Color(0xFF9C4DCC),
                    icon: Icons.notifications_active_rounded,
                  ),
                if (task.skipped)
                  const Pill(label: 'متخطّاة', color: Colors.blueGrey, icon: Icons.skip_next_rounded),
              ],
            ),
            if (plan != null) ...<Widget>[
              const SizedBox(height: 14),
              AppCard(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PlanDetailsScreen(planId: plan.id)),
                  );
                },
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.repeat_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('task.fromPlan', <String, String>{'name': plan.title}),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, size: 20),
                  ],
                ),
              ),
            ],
            if (task.notes.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(context.tr('task.notes'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(task.notes, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (task.subtasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(context.tr('task.subtasks'), style: Theme.of(context).textTheme.labelMedium),
                  ),
                  Text(
                    context.tr('task.subtaskProgress', <String, String>{
                      'a': context.numStr(task.subtaskDone),
                      'b': context.numStr(task.subtasks.length),
                    }),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ThinProgress(value: task.progress, color: catColor, height: 6),
              const SizedBox(height: 10),
              for (final Subtask subtask in task.subtasks)
                CheckboxListTile(
                  value: subtask.done,
                  onChanged: (_) => context.appRead.toggleSubtask(task.id, subtask.id),
                  title: Text(
                    subtask.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: subtask.done ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
            if (task.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String tag in task.tags)
                    Pill(label: '#$tag', color: context.palette.seed),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      successHaptic(context);
                      context.appRead.setTaskDone(task.id, !task.done);
                      Navigator.of(context).pop();
                    },
                    icon: Icon(task.done ? Icons.undo_rounded : Icons.check_rounded),
                    label: Text(task.done ? context.tr('task.markUndone') : context.tr('task.markDone')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _action(
                  context,
                  icon: Icons.edit_rounded,
                  label: context.tr('common.edit'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(taskId: task.id)),
                    );
                  },
                ),
                _action(
                  context,
                  icon: Icons.snooze_rounded,
                  label: context.tr('task.snooze'),
                  onTap: () async {
                    await context.appRead.snoozeTask(task.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(context.tr('toast.snoozed', <String, String>{
                            'n': context.numStr(context.st.snoozeMinutes),
                          })),
                        ));
                    }
                  },
                ),
                _action(
                  context,
                  icon: Icons.event_repeat_rounded,
                  label: context.tr('common.tomorrow'),
                  onTap: () {
                    context.appRead.moveTaskToTomorrow(task.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _action(
                  context,
                  icon: Icons.timer_rounded,
                  label: context.tr('focus.title'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => FocusScreen(taskId: task.id)),
                    );
                  },
                ),
                _action(
                  context,
                  icon: task.skipped ? Icons.undo_rounded : Icons.skip_next_rounded,
                  label: context.tr(task.skipped ? 'task.unskip' : 'task.markSkip'),
                  onTap: () {
                    context.appRead.skipTask(task.id, !task.skipped);
                    Navigator.of(context).pop();
                  },
                ),
                _action(
                  context,
                  icon: Icons.delete_outline_rounded,
                  label: context.tr('common.delete'),
                  danger: true,
                  onTap: () async {
                    final bool confirmed = await showConfirmDialog(
                      context,
                      title: context.tr('common.delete'),
                      message: context.tr('task.deleteConfirm'),
                    );
                    if (confirmed) {
                      final NavigatorState navigator = Navigator.of(context);
                      await context.appRead.deleteTask(task.id);
                      navigator.pop();
                    }
                  },
                ),
              ],
            ),
            if (task.completedAt != null) ...<Widget>[
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '${context.tr('task.stateDone')} • ${context.dateStr(Dates.day(task.completedAt!))} '
                  '${context.timeStr(task.completedAt!.hour * 60 + task.completedAt!.minute)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final Color color = danger ? const Color(0xFFE05B5B) : context.palette.seed;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

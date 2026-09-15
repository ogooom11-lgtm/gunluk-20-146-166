import 'package:flutter/material.dart';

import '../../core/models/plan.dart';
import '../../core/models/stats.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/progress_ring.dart';
import '../widgets/settings_tiles.dart';
import 'plans_screen.dart';
import 'task_editor_screen.dart';

/// تفاصيل الخطة: التقدّم، أيام الدوام، الأيام القادمة، والسجل.
class PlanDetailsScreen extends StatelessWidget {
  const PlanDetailsScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final Plan? plan = app.planById(planId);
    if (plan == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final PlanStats stats = app.planStats(plan);
    final Color color = app.categoryColor(plan.categoryId);
    final double progress =
        stats.scheduledTotal == 0 ? 0 : (stats.doneCount / stats.scheduledTotal).clamp(0.0, 1.0);
    final DateTime today = Dates.today();

    final List<DateTime> upcoming = <DateTime>[];
    DateTime cursor = today;
    for (int i = 0; i < 60 && upcoming.length < 8; i++) {
      if (plan.occursOn(cursor)) upcoming.add(cursor);
      cursor = Dates.addDays(cursor, 1);
    }

    final List<DateTime> history = <DateTime>[];
    DateTime back = Dates.addDays(today, -1);
    for (int i = 0; i < 120 && history.length < 10; i++) {
      if (plan.occursOn(back)) history.add(back);
      back = Dates.addDays(back, -1);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(planId: plan.id)),
            ),
            icon: const Icon(Icons.edit_rounded),
            tooltip: context.tr('common.edit'),
          ),
          IconButton(
            onPressed: () async {
              await app.setPlanPaused(plan.id, !plan.paused);
            },
            icon: Icon(plan.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            tooltip: context.tr(plan.paused ? 'plan.resume' : 'plan.pause'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(18),
            gradient: LinearGradient(
              colors: <Color>[
                color.withAlpha(context.isDark ? 90 : 26),
                color.withAlpha(context.isDark ? 40 : 12),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            child: Row(
              children: <Widget>[
                ProgressRing(
                  value: progress,
                  size: 104,
                  stroke: 11,
                  color: color,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '${context.numStr((progress * 100).round())}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(context.tr('plan.progress'), style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(planRepeatText(context, plan), style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        plan.endDate == null
                            ? context.tr('plan.openEnded')
                            : context.tr('plan.endsOn', <String, String>{'d': context.dateStr(plan.endDate!)}),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          Pill(
                            label: switch (plan.statusAt(DateTime.now())) {
                              PlanStatus.active => context.tr('plan.active'),
                              PlanStatus.paused => context.tr('plan.paused'),
                              PlanStatus.finished => context.tr('plan.finished'),
                              PlanStatus.notStarted => context.tr('plan.notStarted'),
                            },
                            color: color,
                            dense: true,
                          ),
                          Pill(
                            label: context.tr('plan.weekSummary', <String, String>{
                              'done': context.numStr(stats.weekDone),
                              'total': context.numStr(stats.weekTotal),
                            }),
                            color: const Color(0xFF3E8FD8),
                            dense: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: context.tr('plan.summary'), icon: Icons.analytics_rounded),
          _statsGrid(context, stats),
          const SizedBox(height: 18),
          SectionHeader(
            title: context.tr('plan.upcoming'),
            subtitle: context.tr('plan.timeline'),
            icon: Icons.event_available_rounded,
          ),
          if (upcoming.isEmpty)
            AppCard(child: Text(context.tr('plan.finished'), style: Theme.of(context).textTheme.bodySmall))
          else
            for (final DateTime day in upcoming) ...<Widget>[
              _occurrenceTile(context, plan, day, color, isUpcoming: true),
              const SizedBox(height: 8),
            ],
          if (history.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            SectionHeader(title: context.tr('plan.history'), icon: Icons.history_rounded),
            for (final DateTime day in history) ...<Widget>[
              _occurrenceTile(context, plan, day, color, isUpcoming: false),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.general'),
            children: <Widget>[
              SettingsTile(
                title: context.tr('plan.skipDay'),
                subtitle: context.dateStr(today),
                icon: Icons.skip_next_rounded,
                onTap: () => app.togglePlanSkipDay(plan.id, today),
              ),
              SettingsTile(
                title: context.tr(plan.paused ? 'plan.resume' : 'plan.pause'),
                icon: Icons.pause_circle_outline_rounded,
                onTap: () => app.setPlanPaused(plan.id, !plan.paused),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(BuildContext context, PlanStats stats) {
    final List<List<Object>> items = <List<Object>>[
      <Object>['plan.daysCount', stats.spanDays, Icons.date_range_rounded],
      <Object>['plan.scheduledDays', stats.scheduledTotal, Icons.event_repeat_rounded],
      <Object>['plan.workDays', stats.workDays, Icons.work_outline_rounded],
      <Object>['plan.restDays', stats.restDays, Icons.weekend_rounded],
      <Object>['plan.doneDays', stats.doneCount, Icons.check_circle_rounded],
      <Object>['plan.missedDays', stats.missedCount, Icons.error_outline_rounded],
      <Object>['plan.remainingDays', stats.remainingCount, Icons.pending_actions_rounded],
      <Object>['plan.planStreak', stats.streak, Icons.local_fire_department_rounded],
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: <Widget>[
        for (final List<Object> item in items)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(item[2] as IconData, size: 16, color: context.palette.seed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(item[0] as String),
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 2,
                  ),
                ),
                Text(
                  context.numStr(item[1] as int),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _occurrenceTile(
    BuildContext context,
    Plan plan,
    DateTime day,
    Color color, {
    required bool isUpcoming,
  }) {
    final app = context.appRead;
    final Task? task = app.taskFor(plan.id, day);
    final bool done = task?.done ?? false;
    final bool skipped = task?.skipped ?? false;
    final bool missed = !isUpcoming && !done && !skipped;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () async {
        if (isUpcoming) {
          showConfirmDialog(
            context,
            title: context.tr('plan.skipDay'),
            message: context.dateStr(day),
            confirmLabel: context.tr('plan.skipDay'),
            danger: false,
          ).then((bool confirmed) {
            if (confirmed) app.togglePlanSkipDay(plan.id, day);
          });
        }
      },
      child: Row(
        children: <Widget>[
          Column(
            children: <Widget>[
              Text(
                context.numStr(day.day),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(context.weekdayStr(day, short: true), style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.dateStr(day), style: Theme.of(context).textTheme.bodyMedium),
                if (plan.hasTime)
                  Text(context.timeStr(plan.startMinutes!), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          if (skipped)
            Pill(label: context.tr('plan.skippedDay'), color: Colors.blueGrey, dense: true)
          else if (missed)
            Pill(label: context.tr('task.stateMissed'), color: const Color(0xFFE05B5B), dense: true)
          else
            GestureDetector(
              onTap: () async {
                if (task == null) return;
                successHaptic(context);
                await app.toggleTaskDone(task.id);
              },
              child: Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: done ? color : Theme.of(context).textTheme.bodySmall?.color,
                size: 26,
              ),
            ),
        ],
      ),
    );
  }
}

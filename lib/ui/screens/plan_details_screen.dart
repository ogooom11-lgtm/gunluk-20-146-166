import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/date_names.dart';
import '../../core/models/plan.dart';
import '../../core/models/stats.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/amount_sheet.dart';
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
          if (plan.isQuantified) ...<Widget>[
            const SizedBox(height: 18),
            _QuantCard(plan: plan, color: color),
          ],
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

/// بطاقة الخطة الكمّية: كم أنجزت من الهدف، مطلوب اليوم، وجدول الأيام القادمة.
///
/// المطلوب اليومي **يتعدّل تلقائيًا** حسب ما تسجّله: أنجزت أكثر ⇒ يقلّ
/// مطلوب الأيام القادمة، أنجزت أقل ⇒ يرتفع — حتى يكتمل الهدف في تاريخه.
class _QuantCard extends StatelessWidget {
  const _QuantCard({required this.plan, required this.color});

  final Plan plan;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final DateTime today = Dates.today();
    final double required = plan.requiredOn(today);
    final double doneToday = plan.progressOn(today);
    final bool allDone = plan.remainingAmount <= 0;
    final List<PlanDayAmount> schedule = plan.schedule(from: today, maxDays: 12);
    final String unit = plan.unit;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_graph_rounded, size: 19, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('quant.overview'), style: Theme.of(context).textTheme.titleSmall),
              ),
              Pill(
                label: context.tr('quant.badge'),
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${formatAmount(context, plan.doneAmount)} / ${formatAmount(context, plan.totalTarget)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: Theme.of(context).textTheme.labelMedium),
              ),
              const Spacer(),
              Text(
                '${context.numStr((plan.amountRatio * 100).round())}%',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ThinProgress(value: plan.amountRatio, color: color, height: 9),
          const SizedBox(height: 10),
          Text(
            allDone
                ? context.tr('quant.allDone')
                : context.tr('quant.remaining', <String, String>{
                    'v': formatAmount(context, plan.remainingAmount),
                    'unit': unit,
                  }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (!allDone)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(context.isDark ? 36 : 16),
                borderRadius: BorderRadius.circular(16 * context.st.radiusScale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.today_rounded, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(context.tr('quant.todayRequired'), style: Theme.of(context).textTheme.labelMedium),
                      const Spacer(),
                      Text(
                        context.tr('quant.dailyTarget', <String, String>{
                          'v': formatAmount(context, required),
                          'unit': unit,
                        }),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('quant.doneToday', <String, String>{
                      'v': formatAmount(context, doneToday),
                      'unit': unit,
                    }),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  AmountBar(done: doneToday, target: required, unit: unit, color: color),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey<String>('quant_log_button'),
                          onPressed: () => showPlanAmountSheet(context, planId: plan.id, day: today),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: Text(context.tr('quant.log')),
                        ),
                      ),
                      if (required > 0 && doneToday + 0.0001 < required) ...<Widget>[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          key: const ValueKey<String>('quant_full_button'),
                          onPressed: () => app.logPlanAmount(plan.id, today, required),
                          child: Text(context.tr('quant.markDoneFull')),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(Icons.calendar_view_week_rounded, size: 17, color: color),
              const SizedBox(width: 7),
              Text(context.tr('quant.schedule'), style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          Text(context.tr('quant.scheduleHint'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          if (schedule.isEmpty)
            Text(context.tr('quant.noDays'), style: Theme.of(context).textTheme.bodySmall)
          else
            for (final PlanDayAmount item in schedule) ...<Widget>[
              _quantDayRow(context, plan, item, color),
              const SizedBox(height: 6),
            ],
          if (plan.restWeekdays.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(context.tr('quant.restDays'), style: Theme.of(context).textTheme.labelMedium),
                for (final int weekday in (plan.restWeekdays.toList()..sort()))
                  Pill(
                    label: DateNames.weekday(
                      Dates.addDays(DateTime(2024, 1, 1), weekday - 1),
                      context.langCode,
                    ),
                    color: Colors.blueGrey,
                    dense: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quantDayRow(BuildContext context, Plan plan, PlanDayAmount item, Color color) {
    final bool isToday = Dates.sameDay(item.day, Dates.today());
    final bool met = item.met;
    final bool partial = !met && item.done > 0;
    final String unit = plan.unit;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      shadow: false,
      onTap: () => showPlanAmountSheet(context, planId: plan.id, day: item.day),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Column(
              children: <Widget>[
                Text(context.numStr(item.day.day), style: Theme.of(context).textTheme.titleSmall),
                Text(context.weekdayStr(item.day, short: true), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.tr('quant.dailyTarget', <String, String>{
                          'v': formatAmount(context, item.amount),
                          'unit': unit,
                        }),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (isToday)
                      Pill(label: context.tr('quick.today'), color: color, dense: true)
                    else if (met)
                      Pill(label: context.tr('quant.dayDone'), color: const Color(0xFF2FA86A), dense: true)
                    else if (partial)
                      Pill(label: context.tr('quant.dayPartial'), color: const Color(0xFFE0A02E), dense: true),
                  ],
                ),
                const SizedBox(height: 5),
                AmountBar(
                  done: item.done,
                  target: item.amount,
                  unit: unit,
                  color: met ? const Color(0xFF2FA86A) : color,
                  height: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

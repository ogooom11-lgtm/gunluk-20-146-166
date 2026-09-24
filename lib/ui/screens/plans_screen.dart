import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/date_names.dart';
import '../../core/models/plan.dart';
import '../../core/models/stats.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import 'plan_details_screen.dart';
import 'task_editor_screen.dart';

/// قائمة الخطط المتكررة مع ملخص كل خطة.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<Plan> plans = app.plans;
    final List<Plan> active = plans.where((Plan p) => p.statusAt(DateTime.now()) == PlanStatus.active).toList();
    final List<Plan> paused = plans.where((Plan p) => p.statusAt(DateTime.now()) == PlanStatus.paused).toList();
    final List<Plan> others = plans
        .where((Plan p) {
          final PlanStatus status = p.statusAt(DateTime.now());
          return status != PlanStatus.active && status != PlanStatus.paused;
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('plan.title')),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TaskEditorScreen(initialIsPlan: true)),
            ),
            icon: const Icon(Icons.add_rounded),
            tooltip: context.tr('plan.new'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: plans.isEmpty
          ? EmptyState(
              icon: Icons.repeat_rounded,
              title: context.tr('plan.empty'),
              message: context.tr('plan.emptyHint'),
              actionLabel: context.tr('plan.new'),
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TaskEditorScreen(initialIsPlan: true)),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 130),
              children: <Widget>[
                Text(context.tr('plan.subtitle'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                if (active.isNotEmpty) ...<Widget>[
                  SectionHeader(title: context.tr('plan.active'), icon: Icons.play_circle_rounded),
                  for (final Plan plan in active) ...<Widget>[
                    PlanCard(plan: plan),
                    const SizedBox(height: 12),
                  ],
                ],
                if (paused.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  SectionHeader(title: context.tr('plan.paused'), icon: Icons.pause_circle_rounded),
                  for (final Plan plan in paused) ...<Widget>[
                    PlanCard(plan: plan),
                    const SizedBox(height: 12),
                  ],
                ],
                if (others.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  SectionHeader(title: context.tr('plan.finished'), icon: Icons.done_all_rounded),
                  for (final Plan plan in others) ...<Widget>[
                    PlanCard(plan: plan),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
    );
  }
}

/// بطاقة خطة واحدة.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final PlanStats stats = app.planStats(plan);
    final Color color = app.categoryColor(plan.categoryId);
    final PlanStatus status = plan.statusAt(DateTime.now());
    // الخطة الكمّية: التقدّم بالكمّية المنجزة لا بعدد الأيام.
    final double progress = plan.isQuantified
        ? plan.amountRatio
        : (stats.scheduledTotal == 0 ? 0 : (stats.doneCount / stats.scheduledTotal).clamp(0.0, 1.0));
    final double requiredToday = plan.isQuantified ? plan.requiredOn(Dates.today()) : 0;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlanDetailsScreen(planId: plan.id)),
      ),
      onLongPress: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(planId: plan.id)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withAlpha(context.isDark ? 60 : 30),
                  borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
                ),
                child: Icon(app.categoryIcon(plan.categoryId), color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(plan.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(planRepeatText(context, plan), style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              Pill(
                label: switch (status) {
                  PlanStatus.active => context.tr('plan.active'),
                  PlanStatus.paused => context.tr('plan.paused'),
                  PlanStatus.finished => context.tr('plan.finished'),
                  PlanStatus.notStarted => context.tr('plan.notStarted'),
                },
                color: switch (status) {
                  PlanStatus.active => color,
                  PlanStatus.paused => const Color(0xFFE0A02E),
                  PlanStatus.finished => Colors.blueGrey,
                  PlanStatus.notStarted => context.palette.seed,
                },
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: ThinProgress(value: progress, color: color)),
              const SizedBox(width: 10),
              Text(
                '${context.numStr((progress * 100).round())}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plan.isQuantified) ...<Widget>[
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: <Widget>[
                _fact(
                  context,
                  Icons.auto_graph_rounded,
                  context.tr('quant.doneAmount'),
                  context.tr('quant.ofPair', <String, String>{
                    'done': _amountText(context, plan.doneAmount),
                    'total': _amountText(context, plan.totalTarget),
                    'unit': plan.unit,
                  }).trim(),
                ),
                _fact(
                  context,
                  Icons.today_rounded,
                  context.tr('quant.todayRequired'),
                  context.tr('quant.valueUnit', <String, String>{
                    'v': _amountText(context, requiredToday),
                    'unit': plan.unit,
                  }).trim(),
                ),
              ],
            ),
          ] else
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              _fact(context, Icons.event_available_rounded, context.tr('plan.doneDays'), context.numStr(stats.doneCount)),
              _fact(context, Icons.work_outline_rounded, context.tr('plan.workDays'), context.numStr(stats.workDays)),
              _fact(context, Icons.pending_actions_rounded, context.tr('plan.remainingDays'), context.numStr(stats.remainingCount)),
              _fact(
                context,
                Icons.percent_rounded,
                context.tr('plan.adherence'),
                '${context.numStr((stats.adherence * 100).round())}%',
              ),
            ],
          ),
          if (stats.next != null) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(Icons.event_rounded, size: 14, color: context.palette.seed),
                const SizedBox(width: 6),
                Text(
                  '${context.tr('plan.next')}: ${context.dateStr(stats.next!)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                if (plan.endDate != null)
                  Text(
                    context.tr('plan.endsOn', <String, String>{'d': context.shortDateStr(plan.endDate!)}),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 5),
        Text('$label: ', style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

}

/// نصّ كمّية بلا أصفار زائدة (٦٠ لا ٦٠٫٠).
String _amountText(BuildContext context, double value) {
  final String text =
      value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
  return context.numStr(text);
}

/// وصف نصي لتكرار الخطة (يُستخدم في أكثر من شاشة).
String planRepeatText(BuildContext context, Plan plan) {
  if (plan.isQuantified) return context.tr('quant.repeatAll');
  switch (plan.repeatType) {
    case RepeatType.daily:
      return context.tr('repeat.daily');
    case RepeatType.weekly:
      return DateNames.repeatLabel(
        plan.weekdays,
        context.langCode,
        arabicDigits: context.st.arabicDigits,
      );
    case RepeatType.interval:
      return '${context.tr('plan.intervalDays')} ${context.numStr(plan.intervalDays)}';
    case RepeatType.monthly:
      return '${context.tr('plan.dayOfMonth')} ${context.numStr(plan.dayOfMonth)}';
  }
}

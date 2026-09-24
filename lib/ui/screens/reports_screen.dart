import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/plan.dart';
import '../../core/models/stats.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/progress_ring.dart';

/// شاشة التقارير والإحصاءات.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _range = 7;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final StatsSummary summary = app.summary(days: _range);
    final StatsSummary previous = app.summary(days: _range, offset: _range);
    final StatsSummary heat = app.summary(days: 112);
    final int perfect = summary.perfectDays;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBack,
        title: Text(context.tr('stats.title')),
        actions: <Widget>[
          IconButton(
            onPressed: () => _exportReport(context, summary),
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: context.tr('stats.export'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, widget.showBack ? 40 : 130),
        children: <Widget>[
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              ButtonSegment<int>(value: 7, label: Text(context.tr('stats.range7'))),
              ButtonSegment<int>(value: 30, label: Text(context.tr('stats.range30'))),
              ButtonSegment<int>(value: 90, label: Text(context.tr('stats.range90'))),
            ],
            selected: <int>{_range},
            onSelectionChanged: (Set<int> value) => setState(() => _range = value.first),
          ),
          const SizedBox(height: 16),
          if (!summary.hasData)
            AppCard(
              child: Column(
                children: <Widget>[
                  Icon(Icons.insights_rounded, size: 32, color: context.palette.seed),
                  const SizedBox(height: 10),
                  Text(context.tr('stats.noData'), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          else ...<Widget>[
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  ProgressRing(
                    value: summary.rate,
                    size: 118,
                    stroke: 12,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '${context.numStr((summary.rate * 100).round())}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(context.tr('stats.completionRate'), style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _row(context, 'stats.completedCount', context.numStr(summary.done), Colors.green),
                        _row(context, 'stats.missedCount', context.numStr(summary.missed), const Color(0xFFE05B5B)),
                        _row(context, 'stats.totalCount', context.numStr(summary.total), context.palette.seed),
                        _row(context, 'stats.perfectDays', context.numStr(perfect), const Color(0xFFE0A02E)),
                        _row(context, 'stats.dailyAverage', context.numStr(summary.averagePerDay), const Color(0xFF9C4DCC)),
                        _row(context, 'stats.focusTime', context.durStr(summary.focusMinutes), const Color(0xFF2FA8A0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('calendar.weekSummary'), icon: Icons.bar_chart_rounded),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: WeekBars(
                days: summary.days.length > 7 ? summary.days.sublist(summary.days.length - 7) : summary.days,
                labels: <String>[
                  for (final DayStat day in (summary.days.length > 7
                      ? summary.days.sublist(summary.days.length - 7)
                      : summary.days))
                    context.weekdayStr(day.day, short: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('stats.byCategory'), icon: Icons.donut_large_rounded),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: _categoryBreakdown(context, summary),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('stats.byHour'), icon: Icons.access_time_rounded),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: HourBars(hourCounts: summary.doneByHour),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('stats.weekdaysPattern'), icon: Icons.view_week_rounded),
            AppCard(padding: const EdgeInsets.all(16), child: _weekdayPattern(context, summary)),
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('stats.heatmap'), icon: Icons.grid_on_rounded),
            AppCard(padding: const EdgeInsets.all(16), child: Heatmap(days: heat.days)),
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('stats.insights'), icon: Icons.lightbulb_rounded),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (summary.bestDay != null)
                    _insight(
                      context,
                      Icons.star_rounded,
                      context.tr('stats.insightBestDay', <String, String>{
                        'day': context.dateStr(summary.bestDay!),
                      }),
                    ),
                  if (summary.topHour != null)
                    _insight(
                      context,
                      Icons.schedule_rounded,
                      context.tr('stats.insightBestHour', <String, String>{
                        'hour': context.timeStr(summary.topHour! * 60),
                      }),
                    ),
                  if (summary.topCategory != 'general' && summary.topCategory.isNotEmpty)
                    _insight(
                      context,
                      Icons.category_rounded,
                      context.tr('stats.insightCategory', <String, String>{
                        'cat': app.categoryName(summary.topCategory),
                      }),
                    ),
                  if (previous.total > 0)
                    _insight(
                      context,
                      summary.rate >= previous.rate ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      context.tr(
                        summary.rate >= previous.rate ? 'stats.insightTrend' : 'stats.insightTrendDown',
                        <String, String>{
                          'n': context.numStr(((summary.rate - previous.rate).abs() * 100).round()),
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (app.plans.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              SectionHeader(title: context.tr('stats.plansAdherence'), icon: Icons.repeat_rounded),
              for (final Plan plan in app.plans) ...<Widget>[
                _planAdherence(context, plan),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${context.tr('stats.xpTotal')}: ${context.numStr(summary.totalXp)} • '
                '${context.tr('home.level', <String, String>{'n': context.numStr(app.level)})}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String key, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr(key), style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _categoryBreakdown(BuildContext context, StatsSummary summary) {
    if (summary.doneByCategory.isEmpty) {
      return Text(context.tr('stats.noData'), style: Theme.of(context).textTheme.bodySmall);
    }
    final app = context.app;
    final Map<String, Color> colors = <String, Color>{
      for (final String key in summary.doneByCategory.keys) key: app.categoryColor(key),
    };
    final List<MapEntry<String, int>> entries = summary.doneByCategory.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    return Row(
      children: <Widget>[
        DonutChart(
          values: summary.doneByCategory,
          colors: colors,
          size: 132,
          stroke: 18,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                context.numStr(summary.done),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(context.tr('stats.completedCount'), style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final MapEntry<String, int> entry in entries.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: colors[entry.key], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.categoryName(entry.key),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${context.numStr(entry.value)} (${context.numStr((entry.value / summary.done * 100).round())}%)',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekdayPattern(BuildContext context, StatsSummary summary) {
    final int maxValue = summary.doneByWeekday.values.fold<int>(1, (int a, int b) => a > b ? a : b);
    return Column(
      children: <Widget>[
        for (int weekday = 1; weekday <= 7; weekday++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 62,
                  child: Text(
                    context.weekdayStr(Dates.addDays(DateTime(2024, 1, 1), weekday - 1), short: true),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: ThinProgress(
                    value: (summary.doneByWeekday[weekday] ?? 0) / maxValue,
                    height: 9,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 26,
                  child: Text(
                    context.numStr(summary.doneByWeekday[weekday] ?? 0),
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _insight(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: context.palette.seed),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _planAdherence(BuildContext context, Plan plan) {
    final app = context.app;
    final PlanStats stats = app.planStats(plan);
    final Color color = app.categoryColor(plan.categoryId);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(plan.title, style: Theme.of(context).textTheme.titleSmall)),
              Text(
                '${context.numStr((stats.adherence * 100).round())}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ThinProgress(value: stats.adherence, color: color),
          const SizedBox(height: 8),
          Text(
            '${context.tr('plan.workDays')}: ${context.numStr(stats.workDays)} • '
            '${context.tr('plan.doneDays')}: ${context.numStr(stats.doneCount)} • '
            '${context.tr('plan.missedDays')}: ${context.numStr(stats.missedCount)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport(BuildContext context, StatsSummary summary) async {
    final app = context.appRead;
    final StringBuffer buffer = StringBuffer()
      ..writeln('${context.tr('app.name')} — ${context.tr('stats.title')}')
      ..writeln('${context.tr('common.from')}: ${context.dateStr(summary.from)}')
      ..writeln('${context.tr('common.to')}: ${context.dateStr(summary.to)}')
      ..writeln('${context.tr('stats.completionRate')}: ${(summary.rate * 100).round()}%')
      ..writeln('${context.tr('stats.completedCount')}: ${summary.done}')
      ..writeln('${context.tr('stats.missedCount')}: ${summary.missed}')
      ..writeln('${context.tr('stats.totalCount')}: ${summary.total}')
      ..writeln('${context.tr('stats.focusTime')}: ${context.durStr(summary.focusMinutes)}')
      ..writeln('${context.tr('stats.currentStreak')}: ${context.numStr(app.currentStreak)}')
      ..writeln('${context.tr('stats.bestStreak')}: ${context.numStr(app.bestStreak)}')
      ..writeln('${context.tr('stats.xpTotal')}: ${summary.totalXp}');
    summary.doneByCategory.forEach((String key, int value) {
      buffer.writeln('- ${app.categoryName(key)}: $value');
    });
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('stats.exportDone'))));
    }
  }
}

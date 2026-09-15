import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/plan.dart';
import '../../core/models/stats.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../../data/defaults.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/day_timeline.dart';
import '../widgets/progress_ring.dart';
import '../widgets/selectors.dart';
import '../widgets/task_tile.dart';
import 'achievements_screen.dart';
import 'focus_screen.dart';
import 'plan_details_screen.dart';
import 'reports_screen.dart';
import 'search_screen.dart';

/// الصفحة الرئيسية: ملخص اليوم، المهام، الخطط، والعبارة التحفيزية.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenCalendar});

  final ValueChanged<DateTime> onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<Task> today = app.todayTasks;
    final List<Task> active = today.where((Task t) => !t.skipped).toList();
    final int done = active.where((Task t) => t.done).length;
    final List<Task> overdue = app.overdueTasks;
    final StatsSummary week = app.summary(days: 7);
    final DateTime now = DateTime.now();
    final int endOfDay = 23 * 60 + 59;
    final int remainingMinutes = endOfDay - (now.hour * 60 + now.minute);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 120),
          children: <Widget>[
            _header(context),
            const SizedBox(height: 16),
            if (!app.systemNotificationsAllowed) ...<Widget>[
              _notificationsBanner(context),
              const SizedBox(height: 12),
            ],
            _progressCard(context, done: done, total: active.length, remainingMinutes: remainingMinutes),
            const SizedBox(height: 12),
            _statsRow(context, week),
            if (overdue.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _overdueCard(context, overdue),
            ],
            if (today.isNotEmpty && done == active.length && active.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _celebrationCard(context),
            ],
            const SizedBox(height: 20),
            if (app.plans.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: context.tr('home.plansToday'),
                icon: Icons.repeat_rounded,
                actionLabel: context.tr('home.seeAll'),
                onAction: () {},
              ),
              _plansToday(context),
              const SizedBox(height: 20),
            ],
            SectionHeader(
              title: context.tr('home.todayTasks'),
              subtitle: context.tr('home.progressToday'),
              icon: Icons.checklist_rounded,
              actionLabel: context.tr('common.add'),
              onAction: () => onOpenCalendar(Dates.today()),
            ),
            if (active.isEmpty)
              AppCard(
                child: Column(
                  children: <Widget>[
                    Icon(Icons.emoji_objects_rounded, size: 34, color: context.palette.seed),
                    const SizedBox(height: 10),
                    Text(context.tr('home.noTasksToday'), style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(context.tr('home.addFirstTask'), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )
            else
              for (final Task task in active) ...<Widget>[
                TaskTile(task: task, dense: false),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 10),
            SectionHeader(
              title: context.tr('calendar.weekSummary'),
              icon: Icons.insights_rounded,
              actionLabel: context.tr('nav.reports'),
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReportsScreen(showBack: true)),
              ),
            ),
            AppCard(
              child: WeekBars(
                days: week.days,
                labels: <String>[
                  for (final DayStat day in week.days) context.weekdayStr(day.day, short: true),
                ],
                onTap: (DateTime day) => onOpenCalendar(day),
              ),
            ),
            const SizedBox(height: 20),
            _focusCard(context),
            if (app.settings.showQuotes) ...<Widget>[
              const SizedBox(height: 12),
              _quoteCard(context),
            ],
            const SizedBox(height: 12),
            _journalCard(context),
            if (today.where((Task t) => t.hasTime).isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              SectionHeader(title: context.tr('calendar.hours'), icon: Icons.schedule_rounded),
              DayTimeline(day: Dates.today(), tasks: active),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final app = context.app;
    final DateTime now = DateTime.now();
    final String greeting = now.hour < 12
        ? context.tr('home.goodMorning')
        : now.hour < 17
            ? context.tr('home.goodAfternoon')
            : now.hour < 22
                ? context.tr('home.goodEvening')
                : context.tr('home.goodNight');
    final String name = app.settings.name.trim();
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name.isEmpty
                    ? greeting
                    : context.tr('home.withName', <String, String>{'greeting': greeting, 'name': name}),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                app.settings.showHijri
                    ? '${context.dateStr(now)} • ${context.hijriStr(now)}'
                    : context.dateStr(now),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => onOpenCalendar(Dates.today()),
          icon: const Icon(Icons.calendar_today_rounded, size: 20),
          tooltip: context.tr('calendar.title'),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
          ),
          icon: const Icon(Icons.search_rounded, size: 22),
          tooltip: context.tr('search.title'),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
          ),
          icon: const Icon(Icons.emoji_events_outlined, size: 22),
          tooltip: context.tr('badges.title'),
        ),
      ],
    );
  }

  Widget _notificationsBanner(BuildContext context) {
    return AppCard(
      color: const Color(0xFFE0A02E).withAlpha(context.isDark ? 40 : 26),
      onTap: () async {
        await context.appRead.notifications.requestNotificationPermission();
        await context.appRead.refreshSystemNotificationState();
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.notifications_off_rounded, color: Color(0xFFE0A02E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('home.notificationsOff'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Icon(Icons.chevron_left_rounded, size: 20),
        ],
      ),
    );
  }

  Widget _progressCard(BuildContext context, {required int done, required int total, required int remainingMinutes}) {
    final app = context.app;
    final double rate = total == 0 ? 0 : done / total;
    final bool allDone = total > 0 && done == total;
    final int goal = app.settings.dailyGoal;
    final Color base = context.palette.seed;

    return AppCard(
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        colors: <Color>[
          context.palette.gradient.first.withAlpha(context.isDark ? 150 : 26),
          context.palette.gradient.last.withAlpha(context.isDark ? 90 : 14),
        ],
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
      child: Row(
        children: <Widget>[
          ProgressRing(
            value: rate,
            size: 108,
            stroke: 11,
            color: base,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${context.numStr((rate * 100).round())}%',
                  style: AppTheme.numeric(context, factor: 1.15, color: base),
                ),
                Text(context.tr('common.completed'), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  allDone ? context.tr('home.dayComplete') : context.tr('home.todaySummary'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('home.doneOfTotal', <String, String>{
                    'a': context.numStr(done),
                    'b': context.numStr(total),
                  }),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Pill(
                      label: total - done > 0
                          ? context.tr('home.remainingCount', <String, String>{'n': context.numStr(total - done)})
                          : context.tr('notif.nothingPending'),
                      color: base,
                      icon: total - done > 0 ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  remainingMinutes > 0
                      ? context.tr('home.timeLeft', <String, String>{
                          't': context.durStr(remainingMinutes),
                        })
                      : context.tr('home.dayEnded'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (goal > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  ThinProgress(value: done / goal, color: base, height: 6),
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr('settings.dailyGoal')}: ${context.numStr(done)}/${context.numStr(goal)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(BuildContext context, StatsSummary week) {
    final app = context.app;
    final int level = app.level;
    final String levelName = 'badge.levelName${level.clamp(1, 6)}';
    return Row(
      children: <Widget>[
        Expanded(
          child: StatTile(
            label: context.tr('home.streak'),
            value: context.tr('home.streakDays', <String, String>{'n': context.numStr(app.currentStreak)}),
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFE08A2E),
            caption: '${context.tr('stats.bestStreak')}: ${context.numStr(app.bestStreak)}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: context.tr('home.level', <String, String>{'n': context.numStr(level)}),
            value: context.tr(levelName),
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFF9C4DCC),
            caption: context.tr('home.xpToNext', <String, String>{'n': context.numStr(app.xpToNextLevel)}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: context.tr('home.weekRate'),
            value: context.numStr(week.done),
            icon: Icons.insights_rounded,
            color: context.palette.seed,
            caption: '${context.numStr((week.rate * 100).round())}%',
          ),
        ),
      ],
    );
  }

  Widget _overdueCard(BuildContext context, List<Task> overdue) {
    return AppCard(
      color: const Color(0xFFE05B5B).withAlpha(context.isDark ? 40 : 22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE05B5B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('home.overdueBanner', <String, String>{'n': context.numStr(overdue.length)}),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final bool confirmed = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: Text(context.tr('task.moveTomorrow')),
                      content: Text(context.tr('home.overdueBanner', <String, String>{'n': context.numStr(overdue.length)})),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(context.tr('common.cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(context.tr('common.confirm')),
                        ),
                      ],
                    ),
                  ) ??
                      false;
                  if (confirmed) {
                    await context.appRead.moveAllPendingToTomorrow();
                  }
                },
                child: Text(context.tr('task.moveTomorrow')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final Task task in overdue.take(3)) ...<Widget>[
            TaskTile(task: task, dense: true, showDate: true),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _celebrationCard(BuildContext context) {
    return AppCard(
      gradient: context.palette.linearGradient,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shadow: false,
      child: Row(
        children: <Widget>[
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('home.dayComplete'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plansToday(BuildContext context) {
    final app = context.app;
    final DateTime today = Dates.today();
    final List<Plan> todays = app.plans.where((Plan p) => p.occursOn(today)).toList();
    final List<Plan> others = app.plans
        .where((Plan p) => !p.occursOn(today) && !p.paused && p.nextOccurrence(today) != null)
        .toList();
    if (todays.isEmpty && others.isEmpty) {
      return AppCard(
        child: Text(context.tr('plan.emptyHint'), style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Column(
      children: <Widget>[
        for (final Plan plan in todays) ...<Widget>[
          _planTodayCard(context, plan),
          const SizedBox(height: 10),
        ],
        if (others.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: others.length,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final Plan plan = others[index];
                final PlanStats stats = app.planStats(plan);
                return SizedBox(
                  width: 220,
                  child: AppCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => PlanDetailsScreen(planId: plan.id)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: app.categoryColor(plan.categoryId),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                plan.title,
                                style: Theme.of(context).textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          stats.next == null
                              ? context.tr('plan.finished')
                              : '${context.tr('plan.next')}: ${context.shortDateStr(stats.next!)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _planTodayCard(BuildContext context, Plan plan) {
    final app = context.app;
    final PlanStats stats = app.planStats(plan);
    final List<Task> occurrences = app
        .tasksOn(Dates.today())
        .where((Task t) => t.planId == plan.id)
        .toList();
    final bool done = occurrences.isNotEmpty && occurrences.every((Task t) => t.done);
    final Color color = app.categoryColor(plan.categoryId);

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlanDetailsScreen(planId: plan.id)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(context.isDark ? 60 : 30),
                  borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                ),
                child: Icon(app.categoryIcon(plan.categoryId), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(plan.title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '${context.tr('plan.doneDays')}: ${context.numStr(stats.doneCount)}/${context.numStr(stats.scheduledTotal)}'
                      ' • ${context.tr('plan.adherence')}: ${context.numStr((stats.adherence * 100).round())}%',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (occurrences.isNotEmpty)
                IconButton(
                  onPressed: () {
                    successHaptic(context);
                    app.toggleTaskDone(occurrences.first.id);
                  },
                  icon: Icon(
                    done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: done ? context.palette.seed : color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ThinProgress(value: stats.scheduledTotal == 0 ? 0 : stats.doneCount / stats.scheduledTotal, color: color),
        ],
      ),
    );
  }

  Widget _focusCard(BuildContext context) {
    final app = context.app;
    final int today = app.focusMinutesToday;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.palette.seed.withAlpha(context.isDark ? 60 : 30),
              borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
            ),
            child: Icon(Icons.timer_rounded, color: context.palette.seed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.tr('focus.title'), style: Theme.of(context).textTheme.titleSmall),
                Text(
                  context.tr('focus.today', <String, String>{'t': context.durStr(today)}),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded),
        ],
      ),
    );
  }

  Widget _quoteCard(BuildContext context) {
    final List<String> quote = Defaults.quoteFor(Dates.today());
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.format_quote_rounded, color: context.palette.seed.withAlpha(180)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quote[0],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (quote[1].isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text('— ${quote[1]}', style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalCard(BuildContext context) {
    final app = context.app;
    final note = app.noteFor(Dates.today());
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.edit_note_rounded, color: context.palette.seed),
              const SizedBox(width: 8),
              Text(context.tr('home.journal'), style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note == null || note.text.isEmpty ? context.tr('home.journalHint') : note.text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 22),
          Text(context.tr('home.mood'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          MoodPicker(
            value: note?.mood ?? -1,
            onChanged: (int value) => app.saveNote(Dates.today(), note?.text ?? '', value),
          ),
          const SizedBox(height: 8),
          _JournalEditor(
            initialText: note?.text ?? '',
            hint: context.tr('home.journalHint'),
            onSave: (String value) => app.saveNote(Dates.today(), value, note?.mood ?? -1),
          ),
        ],
      ),
    );
  }
}

/// محرّر ملاحظة اليوم مع حفظ تلقائي عند الانتهاء.
class _JournalEditor extends StatefulWidget {
  const _JournalEditor({required this.initialText, required this.hint, required this.onSave});

  final String initialText;
  final String hint;
  final ValueChanged<String> onSave;

  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSave(_controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (String value) => widget.onSave(value.trim()),
    );
  }
}

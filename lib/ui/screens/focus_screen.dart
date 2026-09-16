import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/day_note.dart';
import '../../core/models/task.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/progress_ring.dart';

/// مؤقّت التركيز (بومودورو) مرتبط بمهمة أو حر.
///
/// المؤقّت نفسه يعيش في حالة التطبيق (AppState) لا في هذه الشاشة، لذلك يستمر
/// عند مغادرة الشاشة أو التطبيق، مع إشعار دائم فيه شريط تقدّم والوقت المتبقي.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late int _minutes;
  String? _taskId;
  bool _initialized = false;
  int _seenCompleted = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _minutes = context.st.focusMinutes;
    _taskId = widget.taskId;
    _seenCompleted = context.appRead.focusCompletedCount;
  }

  String _clock(int seconds) {
    final int value = seconds < 0 ? 0 : seconds;
    final String mm = (value ~/ 60).toString().padLeft(2, '0');
    final String ss = (value % 60).toString().padLeft(2, '0');
    return '${context.numStr(mm)}:${context.numStr(ss)}';
  }

  /// اسم المهمة المرتبطة بالجلسة الحالية (أو المختارة قبل البدء).
  Task? _linkedTask(BuildContext context) {
    final app = context.app;
    final String? id = app.focusRunning ? app.focusTaskId : _taskId;
    return id == null ? null : app.taskById(id);
  }

  Future<void> _start(BuildContext context) async {
    final app = context.appRead;
    final Task? task = _taskId == null ? null : app.taskById(_taskId!);
    await app.startFocus(
      _minutes,
      taskId: _taskId,
      label: task?.title ?? '',
    );
  }

  Future<void> _startBreak(BuildContext context) async {
    final app = context.appRead;
    await app.startFocus(
      context.st.breakMinutes,
      taskId: null,
      label: '',
      isBreak: true,
    );
  }

  /// يهنّئ عند انتهاء جلسة (يُفعّل مرة واحدة لكل جلسة).
  void _celebrateIfNeeded(BuildContext context) {
    final app = context.appRead;
    if (app.focusCompletedCount == _seenCompleted) return;
    _seenCompleted = app.focusCompletedCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.tr('focus.sessionDone')),
            action: SnackBarAction(
              label: context.tr('focus.break'),
              onPressed: () => _startBreak(context),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final bool running = app.focusRunning;
    final bool paused = app.focusPaused;
    final bool isBreak = running && app.focusIsBreak;
    final Task? task = _linkedTask(context);

    final int total = running ? app.focusTotalSeconds : _minutes * 60;
    final int remaining = running ? app.focusRemainingSeconds : _minutes * 60;
    final double progress = running ? app.focusProgress : 0;
    final int elapsed = running ? app.focusElapsedSeconds : 0;

    final List<FocusSession> sessions = app.sessionsOn(DateTime.now());
    _celebrateIfNeeded(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('focus.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          Center(
            child: ProgressRing(
              value: progress.clamp(0.0, 1.0),
              size: 240,
              stroke: 16,
              color: isBreak ? const Color(0xFF2FA8A0) : context.palette.seed,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(_clock(remaining), style: AppTheme.numeric(context, factor: 2.4)),
                  const SizedBox(height: 4),
                  Text(
                    isBreak
                        ? context.tr('focus.break')
                        : (running ? context.tr('focus.subtitle') : context.tr('focus.duration')),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (running && elapsed > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('focus.elapsed', <String, String>{
                        't': context.durStr((elapsed / 60).ceil()),
                      }),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (running) ...<Widget>[
            const SizedBox(height: 14),
            AppCard(
              color: (isBreak ? const Color(0xFF2FA8A0) : context.palette.seed)
                  .withAlpha(context.isDark ? 40 : 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    paused ? Icons.pause_circle_outline_rounded : Icons.notifications_active_rounded,
                    color: isBreak ? const Color(0xFF2FA8A0) : context.palette.seed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('focus.runningHint'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.notifications_active_rounded, size: 18, color: context.palette.seed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('focus.keepsRunning'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppCard(
            onTap: running
                ? null
                : () async {
                    final String? picked = await showChoiceSheet<String>(
                      context,
                      title: context.tr('focus.pickTask'),
                      value: _taskId ?? '',
                      options: <ChoiceItem<String>>[
                        ChoiceItem<String>(
                          value: '',
                          label: context.tr('focus.noTask'),
                          icon: Icons.all_inclusive_rounded,
                        ),
                        for (final Task item in app.todayTasks)
                          ChoiceItem<String>(
                            value: item.id,
                            label: item.title,
                            icon: app.categoryIcon(item.categoryId),
                            color: app.categoryColor(item.categoryId),
                          ),
                      ],
                    );
                    if (!mounted || picked == null) return;
                    setState(() => _taskId = picked.isEmpty ? null : picked);
                  },
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: <Widget>[
                Icon(
                  task == null ? Icons.all_inclusive_rounded : app.categoryIcon(task.categoryId),
                  color: task == null ? context.palette.seed : app.categoryColor(task.categoryId),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.tr('focus.pickTask'), style: Theme.of(context).textTheme.labelSmall),
                      Text(
                        running
                            ? (app.focusLabel.isEmpty ? context.tr('focus.noTask') : app.focusLabel)
                            : (task?.title ?? context.tr('focus.noTask')),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                if (!running) const Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: !running
                      ? () => _start(context)
                      : (paused ? () => context.appRead.resumeFocus() : () => context.appRead.pauseFocus()),
                  icon: Icon(
                    !running
                        ? Icons.play_arrow_rounded
                        : (paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  ),
                  label: Text(context.tr(
                    !running ? 'focus.start' : (paused ? 'focus.resume' : 'focus.pause'),
                  )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: running ? () => context.appRead.stopFocus() : null,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(context.tr('focus.stop')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('focus.duration'), icon: Icons.timer_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int minutes in <int>[15, 20, 25, 30, 45, 60, 90])
                ChoiceChip(
                  label: Text(context.durStr(minutes)),
                  selected: (running ? app.focusTotalSeconds ~/ 60 : _minutes) == minutes,
                  onSelected: running
                      ? null
                      : (_) => setState(() {
                            _minutes = minutes;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.tune_rounded, size: 16, color: context.palette.seed),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _minutes.toDouble().clamp(5.0, 120.0),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: context.durStr(_minutes),
                  onChanged: running
                      ? null
                      : (double value) => setState(() {
                            _minutes = value.round();
                          }),
                ),
              ),
              Text(context.durStr(_minutes), style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('focus.breakRecorded'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: context.tr('focus.today', <String, String>{'t': ''}).trim(),
                  value: context.durStr(app.focusMinutesToday),
                  icon: Icons.today_rounded,
                  color: context.palette.seed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: context.tr('focus.total', <String, String>{'t': ''}).trim(),
                  value: context.durStr(app.focusMinutesTotal),
                  icon: Icons.hourglass_bottom_rounded,
                  color: const Color(0xFF2FA8A0),
                  caption: context.tr('focus.sessions', <String, String>{'n': context.numStr(sessions.length)}),
                ),
              ),
            ],
          ),
          if (sessions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            SectionHeader(title: context.tr('focus.title'), icon: Icons.history_rounded),
            for (final FocusSession session in sessions.reversed.take(6)) ...<Widget>[
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.timer_outlined, size: 18, color: context.palette.seed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        session.label.isEmpty ? context.tr('focus.noTask') : session.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      context.timeStr(session.start.hour * 60 + session.start.minute),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 10),
                    Text(context.durStr(session.minutes), style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 10),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: <Widget>[
                  Icon(Icons.tips_and_updates_rounded, size: 18, color: context.palette.seed),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('about.tip1'),
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

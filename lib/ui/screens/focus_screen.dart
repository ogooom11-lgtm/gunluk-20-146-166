import 'dart:async';

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
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late int _minutes;
  int _remaining = 0;
  bool _running = false;
  bool _isBreak = false;
  String? _taskId;
  bool _initialized = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _minutes = context.st.focusMinutes;
    _remaining = _minutes * 60;
    _taskId = widget.taskId;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      if (_remaining <= 0) _remaining = _minutes * 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        _finish(sessionMinutes: _minutes);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _stop() {
    final int elapsed = _minutes * 60 - _remaining;
    _timer?.cancel();
    setState(() => _running = false);
    if (elapsed >= 60) {
      _finish(sessionMinutes: elapsed ~/ 60);
    } else {
      setState(() => _remaining = _minutes * 60);
    }
  }

  void _finish({required int sessionMinutes}) {
    final app = context.appRead;
    final Task? task = _taskId == null ? null : app.taskById(_taskId!);
    app.addFocusSession(
      sessionMinutes,
      taskId: _taskId,
      label: task?.title ?? '',
    );
    app.notifications.showInstant(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: context.tr('focus.notifDone'),
      body: context.tr('focus.wellDone', <String, String>{'t': context.durStr(sessionMinutes)}),
      settings: app.settings,
      l10n: app.l10n,
    );
    if (mounted) {
      final int breakMinutes = context.st.breakMinutes;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.tr('focus.wellDone', <String, String>{'t': context.durStr(sessionMinutes)})),
            action: SnackBarAction(
              label: context.tr('focus.break'),
              onPressed: () {
                setState(() {
                  _isBreak = true;
                  _minutes = breakMinutes;
                  _remaining = breakMinutes * 60;
                });
                _start();
              },
            ),
          ),
        );
      setState(() {
        _isBreak = false;
        _remaining = _minutes * 60;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final Task? task = _taskId == null ? null : app.taskById(_taskId!);
    final int total = _minutes * 60;
    final double progress = total == 0 ? 0 : 1 - (_remaining / total);
    final List<FocusSession> sessions = app.sessionsOn(DateTime.now());
    final int round = _remaining ~/ 60;
    final int seconds = _remaining % 60;

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
              color: _isBreak ? const Color(0xFF2FA8A0) : context.palette.seed,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${context.numStr(round.toString().padLeft(2, '0'))}:${context.numStr(seconds.toString().padLeft(2, '0'))}',
                    style: AppTheme.numeric(context, factor: 2.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBreak ? context.tr('focus.break') : context.tr('focus.subtitle'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          AppCard(
            onTap: () async {
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
                      Text(task?.title ?? context.tr('focus.noTask'), style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? _pause : _start,
                  icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(context.tr(_running ? 'focus.pause' : (_remaining < total ? 'focus.resume' : 'focus.start'))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stop,
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
                  selected: _minutes == minutes,
                  onSelected: (_) => setState(() {
                    _minutes = minutes;
                    _remaining = minutes * 60;
                    _isBreak = false;
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
                  onChanged: (double value) => setState(() {
                    _minutes = value.round();
                    _remaining = _minutes * 60;
                    _isBreak = false;
                  }),
                ),
              ),
              Text(context.durStr(_minutes), style: Theme.of(context).textTheme.labelMedium),
            ],
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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/task.dart';
import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../../services/security_gate.dart';

/// شاشة المنبّه: تظهر كاملة وقت استحقاق المهمة العاجلة.
///
/// - الحماية أولًا: لا يظهر أي اسم أو وصف — «منبّه» وساعة كبيرة وزر تأجيل.
/// - زر «إظهار التفاصيل» يطلب التعرّف على الوجه (أو قفل الجهاز أو رمز التطبيق)،
///   وبعد التحقّق فقط يظهر اسم المهمة ووصفها وأزرار الإنجاز والتأجيل.
/// - كل شيء بحركة: جرس ينبض بحلقات، تدرّج يتنفّس، وانتقال ناعم للتفاصيل.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _revealed = false;
  bool _verifying = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // ساعة حيّة كل ثانية (خفيفة: تُحدّث هذه الشاشة فقط).
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  AppState get _app => context.appRead;

  Task? get _task => _app.taskById(widget.taskId);

  Future<void> _reveal() async {
    if (_verifying) return;
    setState(() => _verifying = true);
    final bool ok = await verifyIdentityForAlarm(context);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _revealed = _revealed || ok;
    });
    if (!ok && mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE05B5B),
          content: Text(context.tr('alarm.verifyFailed')),
        ),
      );
    }
  }

  Future<void> _snooze(int minutes) async {
    HapticFeedback.mediumImpact();
    final AppState app = _app;
    await app.snoozeAlarm(minutes);
    if (!mounted) return;
    final DateTime until = DateTime.now().add(Duration(minutes: minutes));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('alarm.snoozed', <String, String>{
          'n': context.numStr(minutes),
          'time': context.hourStr(until.hour * 60 + until.minute),
        })),
      ),
    );
  }

  Future<void> _done() async {
    HapticFeedback.mediumImpact();
    await _app.completeAlarm();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('alarm.doneToast'))),
    );
  }

  Future<void> _pickSnooze() async {
    final int? minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(ctx.gap.screenPadding, 14, ctx.gap.screenPadding, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ctx.tr('alarm.snoozeTitle'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final int n in AppSettings.alarmSnoozeOptions)
                    ActionChip(
                      avatar: const Icon(Icons.snooze_rounded, size: 18),
                      label: Text(n == 1
                          ? ctx.tr('alarm.minute1')
                          : ctx.tr('alarm.snoozeValue', <String, String>{'n': ctx.numStr(n)})),
                      onPressed: () => Navigator.of(ctx).pop(n),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null || !mounted) return;
    await _snooze(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final Task? task = _task;
    final DateTime now = DateTime.now();
    return PopScope(
      // لا يُغلق المنبّه بزر الرجوع: إنجاز أو تأجيل (أو إخفاء مؤقّت).
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                context.palette.seed.withAlpha(context.isDark ? 150 : 70),
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const Spacer(),
                _RingingBell(pulse: _pulse, color: context.palette.seed),
                const SizedBox(height: 18),
                Text(
                  context.tr('alarm.title'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.hourStr(now.hour * 60 + now.minute),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: context.palette.seed,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    _revealed
                        ? (task?.title ?? '')
                        : context.tr('alarm.hiddenHint'),
                    key: ValueKey<bool>(_revealed),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Spacer(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  child: _revealed ? _details(context, task) : _locked(context),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ما يظهر قبل التحقّق: تأجيل فقط + زر إظهار التفاصيل.
  Widget _locked(BuildContext context) {
    return Column(
      children: <Widget>[
        OutlinedButton.icon(
          key: const ValueKey<String>('alarm_reveal'),
          onPressed: _verifying ? null : _reveal,
          icon: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.face_retouching_natural_rounded),
          label: Text(context.tr('alarm.reveal')),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey<String>('alarm_snooze'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          ),
          onPressed: _pickSnooze,
          icon: const Icon(Icons.snooze_rounded),
          label: Text(context.tr('alarm.snooze')),
        ),
      ],
    );
  }

  /// ما يظهر بعد التحقّق: الاسم والوقت والوصف + إنجاز وتأجيل.
  Widget _details(BuildContext context, Task? task) {
    if (task == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Text(context.tr('alarm.hiddenHint'), textAlign: TextAlign.center),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.priority_high_rounded, size: 18, color: task.priority.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (task.notes.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(task.notes, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(Icons.schedule_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      task.startMinutes == null
                          ? context.tr('alarm.clockHint')
                          : context.timeStr(task.startMinutes!),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('alarm_snooze'),
              onPressed: _pickSnooze,
              icon: const Icon(Icons.snooze_rounded),
              label: Text(context.tr('alarm.snooze')),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey<String>('alarm_done'),
              onPressed: _done,
              icon: const Icon(Icons.check_rounded),
              label: Text(context.tr('alarm.done')),
            ),
          ],
        ),
      ],
    );
  }
}

/// جرس يرنّ: نبض + حلقات تتوسّع (رسم خفيف بلا أصول خارجية).
class _RingingBell extends StatelessWidget {
  const _RingingBell({required this.pulse, required this.color});

  final AnimationController pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = pulse.value;
        return SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                _ripple(0.34 + i * 0.33),
              Transform.scale(
                scale: 1 + math.sin(t * math.pi * 2) * 0.045,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: context.palette.linearGradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: color.withAlpha(90), blurRadius: 30, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 54,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// حلقة تتوسّع وتتلاشى مع نبض الجرس.
  Widget _ripple(double offset) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = (pulse.value + offset) % 1.0;
        return Opacity(
          opacity: (1 - t) * 0.5,
          child: Transform.scale(
            scale: 0.55 + t * 1.35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(120), width: 2.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

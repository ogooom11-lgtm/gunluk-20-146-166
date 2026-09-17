import 'dart:convert';

import '../core/enums.dart';
import '../core/l10n/app_strings.dart';
import '../core/l10n/date_names.dart';
import '../core/models/app_settings.dart';
import '../core/models/planned_reminder.dart';
import '../core/models/task.dart';
import '../core/utils/dates.dart';

/// بناء جدول التذكيرات من بيانات التطبيق — منطق خالص قابل للاختبار
/// (بدون أي اعتماد على نظام الإشعارات أو على واجهة المستخدم).
class ReminderPlanner {
  ReminderPlanner._();

  static List<PlannedReminder> build({
    required AppSettings settings,
    required List<Task> tasks,
    required AppLocalizations l10n,
    required int Function(String key) idFor,
    required String Function(String categoryId) categoryName,
    DateTime? now,
    int windowDays = 16,
    int limit = 240,
  }) {
    final DateTime n = now ?? DateTime.now();
    final List<PlannedReminder> out = <PlannedReminder>[];
    if (!settings.notificationsEnabled) return out;

    final bool privacy = settings.privacyMode;
    final String lang = l10n.lang;

    for (int i = 0; i < windowDays; i++) {
      final DateTime day = Dates.addDays(Dates.day(n), i);

      // ===== تذكيرات المهام =====
      for (final Task task in tasks) {
        if (!Dates.sameDay(task.date, day)) continue;
        if (task.done || task.skipped) continue;
        if (task.planId != null && privacy) {
          // في وضع الخصوصية نُبقي التذكيرات لكن بنصوص عامة
        }
        final List<int> minutes = task.reminderMinutes();
        for (final int minute in minutes) {
          final DateTime when = Dates.at(day, minute);
          if (!when.isAfter(n.add(const Duration(seconds: 25)))) continue;
          final bool isLead = task.startMinutes != null && minute < task.startMinutes!;
          final ReminderKind kind = isLead ? ReminderKind.upcoming : ReminderKind.task;
          final String timeText = DateNames.time(task.startMinutes ?? minute,
              use24: settings.use24Hour, lang: lang, arabicDigits: settings.arabicDigits);
          final String title = isLead
              ? l10n.t('notif.upcomingTitle', <String, String>{
                  'n': '${task.startMinutes! - minute}',
                  'title': privacy ? l10n.t('app.name') : task.title,
                })
              : l10n.t('notif.taskTitle', <String, String>{
                  'title': privacy ? l10n.t('app.name') : task.title,
                });
          final String body = isLead
              ? l10n.t('notif.upcomingBody', <String, String>{'time': timeText})
              : l10n.t('notif.taskBody', <String, String>{
                  'time': timeText,
                  'category': categoryName(task.categoryId),
                });
          out.add(PlannedReminder(
            id: idFor('$kind:${task.id}:$minute'),
            key: '$kind:${task.id}:$minute',
            when: when,
            kind: kind,
            title: title,
            body: body,
            payload: 'task:${task.id}',
            taskId: task.id,
            withActions: settings.actionButtons,
          ));
        }

        // ===== منبّه المهام العاجلة =====
        // أي مهمة أولويتها «عاجل» (ومنها مهام الخطط المختار لها عاجل) ترنّ
        // كمنبّه بشاشة كاملة في وقتها — وبخصوصية: «منبّه» فقط حتى التحقّق.
        if (settings.alarmEnabled && task.priority == TaskPriority.urgent) {
          final int? anchor = task.startMinutes ?? task.reminderAtMinutes;
          if (anchor != null) {
            final DateTime when = Dates.at(day, anchor);
            if (when.isAfter(n.add(const Duration(seconds: 25)))) {
              final String alarmTitle =
                  settings.alarmHideDetails ? l10n.t('alarm.title') : task.title;
              final String alarmBody = settings.alarmHideDetails
                  ? l10n.t('alarm.hiddenHint')
                  : l10n.t('notif.taskBody', <String, String>{
                      'time': DateNames.time(anchor,
                          use24: settings.use24Hour,
                          lang: lang,
                          arabicDigits: settings.arabicDigits),
                      'category': categoryName(task.categoryId),
                    });
              out.add(PlannedReminder(
                id: idFor('${ReminderKind.alarm}:${task.id}'),
                key: '${ReminderKind.alarm}:${task.id}',
                when: when,
                kind: ReminderKind.alarm,
                title: alarmTitle,
                body: alarmBody,
                payload: jsonEncode(<String, dynamic>{
                  'o': 'alarm',
                  'k': ReminderKind.alarm.name,
                  'i': task.id,
                }),
                taskId: task.id,
                withActions: true,
                fullScreen: true,
              ));
            }
          }
        }

        // ===== التنبيه المتكرر حتى الإنجاز =====
        if (settings.nudgesEnabled && settings.maxNudges > 0) {
          final int? anchor = task.startMinutes ?? task.reminderAtMinutes;
          if (anchor != null) {
            for (int k = 1; k <= settings.maxNudges; k++) {
              final int minute = anchor + settings.nudgeIntervalMinutes * k;
              if (minute >= 1440) break;
              final DateTime when = Dates.at(day, minute);
              if (!when.isAfter(n.add(const Duration(seconds: 25)))) continue;
              out.add(PlannedReminder(
                id: idFor('${ReminderKind.nudge}:${task.id}:$k'),
                key: '${ReminderKind.nudge}:${task.id}:$k',
                when: when,
                kind: ReminderKind.nudge,
                title: l10n.t('notif.nudgeTitle', <String, String>{
                  'title': privacy ? l10n.t('app.name') : task.title,
                }),
                body: privacy ? l10n.t('notif.nudgeBody') : task.notes.isEmpty ? l10n.t('notif.nudgeBody') : task.notes,
                payload: 'task:${task.id}',
                taskId: task.id,
                withActions: settings.actionButtons,
              ));
            }
          }
        }
      }

      // ===== أجندة الصباح =====
      if (settings.morningEnabled) {
        final DateTime when = Dates.at(day, settings.morningMinutes);
        if (when.isAfter(n)) {
          final List<Task> dayTasks = tasks
              .where((Task t) => Dates.sameDay(t.date, day) && !t.skipped)
              .toList()
            ..sort(_byTime);
          final List<Task> pending = dayTasks.where((Task t) => !t.done).toList();
          final String body = pending.isEmpty
              ? l10n.t('notif.morningEmpty')
              : l10n.t('notif.morningBody', <String, String>{
                  'n': '${pending.length}',
                  'first': pending.first.title,
                });
          out.add(PlannedReminder(
            id: idFor('${ReminderKind.morning}:${Dates.key(day)}'),
            key: '${ReminderKind.morning}:${Dates.key(day)}',
            when: when,
            kind: ReminderKind.morning,
            title: l10n.t('notif.morningTitle'),
            body: body,
            payload: 'morning:${Dates.key(day)}',
            lines: privacy
                ? const <String>[]
                : pending.take(5).map((Task t) => _line(t, settings)).toList(),
            withActions: false,
          ));
        }
      }

      // ===== مراجعة نهاية اليوم =====
      if (settings.eveningEnabled) {
        final DateTime when = Dates.at(day, settings.eveningMinutes);
        if (when.isAfter(n)) {
          final List<Task> dayTasks = tasks.where((Task t) => Dates.sameDay(t.date, day)).toList();
          final List<Task> pending = dayTasks.where((Task t) => !t.done && !t.skipped).toList()
            ..sort(_byTime);
          // المتأخّرة: مهام أيام سابقة لم تُنجز ولم تُتخطَّ (خلال آخر ٦٠ يومًا
          // حتى لا تتراكم المهام القديمة في نص الإشعار).
          // diffDays(a, b) = b - a ⇒ «t.date قبل day» تعني diffDays(day, t.date) < 0.
          final List<Task> overdue = tasks.where((Task t) {
            if (t.done || t.skipped) return false;
            if (Dates.diffDays(t.date, n) < 0) return false; // موعدها في المستقبل
            final int age = Dates.diffDays(day, t.date);
            return age < 0 && age >= -60;
          }).toList()
            ..sort((Task a, Task b) => a.date.compareTo(b.date));

          final String title = l10n.t('notif.summaryTitle');
          final String body = pending.isEmpty && overdue.isEmpty
              ? l10n.t('notif.summaryAllDone')
              : l10n.t('notif.summaryBody', <String, String>{
                  'done': '${dayTasks.where((Task t) => t.done).length}',
                  'total': '${dayTasks.length}',
                  'left': '${pending.length + overdue.length}',
                });

          final List<String> lines = <String>[];
          if (!privacy) {
            for (final Task t in pending.take(5)) {
              lines.add('• ${_line(t, settings)}');
            }
            if (overdue.isNotEmpty) {
              lines.add('⏳ ${l10n.t('notif.overdueTitle', <String, String>{'n': '${overdue.length}'})}');
              for (final Task t in overdue.take(2)) {
                lines.add('• ${t.title}');
              }
            }
            if (pending.isEmpty && overdue.isEmpty) {
              lines.add('🎉 ${l10n.t('notif.nothingPending')}');
            }
          }

          out.add(PlannedReminder(
            id: idFor('${ReminderKind.review}:${Dates.key(day)}'),
            key: '${ReminderKind.review}:${Dates.key(day)}',
            when: when,
            kind: ReminderKind.review,
            title: title,
            body: body,
            payload: 'review:${Dates.key(day)}',
            lines: lines,
            withActions: pending.isNotEmpty || overdue.isNotEmpty,
          ));
        }
      }
    }

    out.sort((PlannedReminder a, PlannedReminder b) => a.when.compareTo(b.when));
    if (out.length > limit) {
      return out.sublist(0, limit);
    }
    return out;
  }

  static int _byTime(Task a, Task b) {
    final int am = a.startMinutes ?? 24 * 60;
    final int bm = b.startMinutes ?? 24 * 60;
    if (am != bm) return am - bm;
    return b.priority.rank - a.priority.rank;
  }

  static String _line(Task task, AppSettings settings) {
    if (task.startMinutes == null) return task.title;
    return '${DateNames.time(task.startMinutes!, use24: settings.use24Hour, lang: settings.isArabic ? 'ar' : 'en', arabicDigits: settings.arabicDigits)} — ${task.title}';
  }
}

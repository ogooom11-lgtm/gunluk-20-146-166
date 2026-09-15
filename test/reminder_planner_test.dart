import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/app_settings.dart';
import 'package:gunluk/core/models/planned_reminder.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/data/reminder_planner.dart';

/// تاريخ مرجعي ثابت لكل الاختبارات: الاثنين ٥ يناير ٢٠٢٦ الساعة ٨ صباحًا.
final DateTime kNow = DateTime(2026, 1, 5, 8);

final AppLocalizations l10n = AppLocalizations.ofLocale(const Locale('ar'));

Task _task({
  required String id,
  required String title,
  required DateTime date,
  int? startMinutes,
  List<int> leads = const <int>[],
  int? reminderAt,
  bool done = false,
  String notes = '',
}) =>
    Task(
      id: id,
      title: title,
      date: date,
      notes: notes,
      startMinutes: startMinutes,
      reminderLeads: List<int>.from(leads),
      reminderAtMinutes: reminderAt,
      done: done,
    );

List<PlannedReminder> _build({
  required AppSettings settings,
  required List<Task> tasks,
  int windowDays = 16,
}) {
  final Map<String, int> ids = <String, int>{};
  return ReminderPlanner.build(
    settings: settings,
    tasks: tasks,
    l10n: l10n,
    idFor: (String key) => ids.putIfAbsent(key, () => 1000 + ids.length),
    categoryName: (String id) => id == 'study' ? 'تعلّم' : 'عام',
    now: kNow,
    windowDays: windowDays,
  );
}

void main() {
  group('تخطيط التذكيرات', () {
    test('تذكير قبل الموعد + مراجعة نهاية اليوم', () {
      final List<PlannedReminder> list = _build(
        settings: AppSettings(),
        tasks: <Task>[_task(id: 'a', title: 'مراجعة', date: kNow, startMinutes: 10 * 60, leads: <int>[30])],
      );

      final List<PlannedReminder> upcoming =
          list.where((PlannedReminder r) => r.kind == ReminderKind.upcoming).toList();
      expect(upcoming.length, 1);
      expect(upcoming.first.when, DateTime(2026, 1, 5, 9, 30));
      expect(upcoming.first.title, contains('مراجعة'));
      expect(upcoming.first.withActions, isTrue);

      final List<PlannedReminder> reviews =
          list.where((PlannedReminder r) => r.kind == ReminderKind.review).toList();
      expect(reviews.length, 16, reason: 'مراجعة واحدة لكل يوم في نافذة التخطيط');
      expect(reviews.first.when, DateTime(2026, 1, 5, 21, 0), reason: 'التذكير الافتراضي ٢١:٠٠');
      expect(reviews.first.lines.any((String line) => line.contains('مراجعة')), isTrue,
          reason: 'الإشعار يسرد ما لم يُنجز بعد');
      expect(reviews.first.withActions, isTrue);
      expect(list.first.when, DateTime(2026, 1, 5, 9, 30), reason: 'الترتيب زمني');
    });

    test('لا تذكيرات للمهام المنجزة أو المتخطّاة أو الماضية', () {
      final List<PlannedReminder> list = _build(
        settings: AppSettings(),
        tasks: <Task>[
          _task(id: 'done', title: 'منجزة', date: kNow, startMinutes: 10 * 60, leads: <int>[30], done: true),
          _task(id: 'past', title: 'قديمة', date: DateTime(2026, 1, 4), startMinutes: 10 * 60, leads: <int>[30]),
          _task(id: 'future', title: 'بلا وقت', date: kNow),
        ],
      );
      expect(list.where((PlannedReminder r) => r.kind != ReminderKind.review), isEmpty);
    });

    test('تذكير بوقت محدّد للمهمة بلا ساعة', () {
      final List<PlannedReminder> list = _build(
        settings: AppSettings(),
        tasks: <Task>[_task(id: 'a', title: 'اتصال', date: kNow, reminderAt: 20 * 60)],
      );
      final List<PlannedReminder> tasks =
          list.where((PlannedReminder r) => r.kind == ReminderKind.task).toList();
      expect(tasks.length, 1);
      expect(tasks.first.when, DateTime(2026, 1, 5, 20, 0));
    });

    test('التنبيهات المتكررة تتوقف عند الحد الأعلى', () {
      final AppSettings settings = AppSettings().copyWith(
        nudgesEnabled: true,
        nudgeIntervalMinutes: 30,
        maxNudges: 2,
      );
      final List<PlannedReminder> list = _build(
        settings: settings,
        tasks: <Task>[_task(id: 'a', title: 'تمرين', date: kNow, startMinutes: 10 * 60, leads: <int>[30])],
      );
      final List<PlannedReminder> nudges =
          list.where((PlannedReminder r) => r.kind == ReminderKind.nudge).toList();
      expect(nudges.length, 2);
      expect(nudges[0].when, DateTime(2026, 1, 5, 10, 30));
      expect(nudges[1].when, DateTime(2026, 1, 5, 11, 0));
      expect(nudges.first.kind.channelId('v1'), 'injaz_nudge_v1');
    });

    test('أجندة الصباح تُدرج المهام المتبقية', () {
      final AppSettings settings = AppSettings().copyWith(morningEnabled: true, morningMinutes: 9 * 60);
      final List<PlannedReminder> list = _build(
        settings: settings,
        tasks: <Task>[
          _task(id: 'a', title: 'ورد القرآن', date: kNow, startMinutes: 6 * 60, leads: <int>[0]),
          _task(id: 'b', title: 'رياضة', date: kNow, startMinutes: 18 * 60, leads: <int>[0]),
        ],
      );
      final List<PlannedReminder> mornings =
          list.where((PlannedReminder r) => r.kind == ReminderKind.morning).toList();
      expect(mornings.length, 16);
      expect(mornings.first.lines.length, 2);
      expect(mornings.first.lines.first, contains('ورد القرآن'));
      expect(mornings.first.withActions, isFalse);
    });

    test('تعطيل الإشعارات يوقف كل الجدولة', () {
      final List<PlannedReminder> list = _build(
        settings: AppSettings().copyWith(notificationsEnabled: false),
        tasks: <Task>[_task(id: 'a', title: 'مراجعة', date: kNow, startMinutes: 10 * 60, leads: <int>[30])],
      );
      expect(list, isEmpty);
    });

    test('وضع الخصوصية يخفي تفاصيل المهام', () {
      final List<PlannedReminder> list = _build(
        settings: AppSettings().copyWith(privacyMode: true),
        tasks: <Task>[
          _task(id: 'a', title: 'جلسة سرية', date: kNow, startMinutes: 10 * 60, leads: <int>[30], notes: 'تفاصيل'),
        ],
      );
      expect(list, isNotEmpty);
      for (final PlannedReminder reminder in list) {
        expect(reminder.title.contains('جلسة سرية'), isFalse);
        expect(reminder.body.contains('تفاصيل'), isFalse);
        expect(reminder.lines, isEmpty);
      }
    });

    test('معرّفات الإشعارات فريدة وثابتة', () {
      final List<PlannedReminder> list = _build(
        settings: AppSettings(),
        tasks: <Task>[_task(id: 'a', title: 'مهمة', date: kNow, startMinutes: 10 * 60, leads: <int>[30, 10])],
      );
      final Set<int> ids = list.map((PlannedReminder r) => r.id).toSet();
      expect(ids.length, list.length);
      expect(list.every((PlannedReminder r) => r.id >= 1000), isTrue);
    });
  });
}

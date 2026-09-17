import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/models/app_settings.dart';
import 'package:gunluk/core/models/subtask.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/core/models/day_note.dart';
import 'package:gunluk/core/utils/dates.dart';
import 'package:gunluk/data/defaults.dart';

Task _task({
  String id = 't1',
  String title = 'قراءة ١٠ صفحات',
  DateTime? date,
  String categoryId = 'study',
  bool done = false,
  bool skipped = false,
  int? startMinutes,
  int durationMinutes = 0,
  List<int> leads = const <int>[],
  String planId = '',
  DateTime? completedAt,
}) =>
    Task(
      id: id,
      title: title,
      date: date ?? DateTime(2026, 1, 5),
      categoryId: categoryId,
      done: done,
      skipped: skipped,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      reminderLeads: List<int>.from(leads),
      planId: planId.isEmpty ? null : planId,
      completedAt: completedAt,
    );

void main() {
  group('Dates', () {
    test('مفتاح اليوم وتحليله', () {
      expect(Dates.key(DateTime(2026, 1, 5)), '2026-01-05');
      expect(Dates.parseKey('2026-01-05'), DateTime(2026, 1, 5));
      expect(Dates.parseKey('bad'), isNull);
      expect(Dates.parseKey(null), isNull);
    });

    test('الفرق بين الأيام والإضافة', () {
      expect(Dates.diffDays(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), 30);
      expect(Dates.addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(Dates.addDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    });

    test('الشهور والسنوات الكبيسة', () {
      expect(Dates.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(Dates.addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(Dates.daysInMonth(2024, 2), 29);
      expect(Dates.daysInMonth(2026, 2), 28);
    });

    test('ترتيب الأسبوع وأول يوم منه', () {
      expect(Dates.weekOrder(DateTime.saturday), <int>[6, 7, 1, 2, 3, 4, 5]);
      expect(Dates.startOfWeek(DateTime(2026, 1, 5), DateTime.monday), DateTime(2026, 1, 5));
      expect(Dates.startOfWeek(DateTime(2026, 1, 5), DateTime.saturday), DateTime(2026, 1, 3));
    });

    test('شبكة الشهر ٤٢ يومًا تبدأ من أول الأسبوع', () {
      final List<DateTime> grid = Dates.monthGrid(DateTime(2026, 1, 1), DateTime.monday);
      expect(grid.length, 42);
      expect(grid.first, DateTime(2025, 12, 29));
      expect(grid[3], DateTime(2026, 1, 1));
    });

    test('الوقت بالدقائق', () {
      expect(Dates.at(DateTime(2026, 1, 5), 21 * 60 + 30), DateTime(2026, 1, 5, 21, 30));
      expect(Dates.timeOf(9 * 60 + 45).hour, 9);
      expect(Dates.timeOf(9 * 60 + 45).minute, 45);
      expect(Dates.timeOf(25 * 60).hour, 1);
      expect(Dates.minutesOf(const TimeOfDay(hour: 7, minute: 15)), 435);
    });

    test('التاريخ الهجري في نطاق منطقي', () {
      final HijriDate hijri = HijriDate.fromGregorian(DateTime(2026, 1, 1));
      expect(hijri.year, inInclusiveRange(1445, 1450));
      expect(hijri.month, inInclusiveRange(1, 12));
      expect(hijri.day, inInclusiveRange(1, 30));
      final HijriDate later = HijriDate.fromGregorian(DateTime(2026, 6, 1));
      expect(later.year * 10000 + later.month * 100 + later.day,
          greaterThan(hijri.year * 10000 + hijri.month * 100 + hijri.day));
    });
  });

  group('Task', () {
    test('أوقات التذكير = الموعد ناقص المهلة', () {
      final Task task = _task(startMinutes: 10 * 60, leads: <int>[30, 10]);
      expect(task.reminderMinutes(), <int>[9 * 60 + 30, 9 * 60 + 50]);
    });

    test('تذكير بالوقت المحدّد للمهام بدون ساعة', () {
      final Task task = _task();
      task.reminderAtMinutes = 20 * 60;
      expect(task.reminderMinutes(), <int>[20 * 60]);
    });

    test('الحالة تُحسب من التاريخ والإنجاز', () {
      final DateTime past = Dates.addDays(Dates.today(), -3);
      expect(_task(date: Dates.today()).state, ItemState.pending);
      expect(_task(date: past).state, ItemState.missed);
      expect(_task(date: past, done: true, completedAt: past).state, ItemState.done);
      expect(_task(date: past, skipped: true).state, ItemState.skipped);
      expect(_task(date: past).isOverdue, isTrue);
      expect(_task(date: Dates.addDays(Dates.today(), 3)).isOverdue, isFalse);
    });

    test('النقاط تعتمد على الأهمية وعدد الخطوات', () {
      expect(_task().xp, TaskPriority.medium.xp);
      final Task withSteps = _task();
      withSteps.subtasks = <Subtask>[Subtask.create('أ'), Subtask.create('ب')];
      expect(withSteps.xp, TaskPriority.medium.xp + 4);
    });

    test('تقدّم الخطوات', () {
      final Task task = _task();
      task.subtasks = <Subtask>[Subtask.create('أ'), Subtask.create('ب', done: true)];
      expect(task.subtaskCount, 2);
      expect(task.subtaskDone, 1);
      expect(task.progress, 0.5);
    });

    test('النسخ بمعرّف جديد ودون نسخ حالة الإنجاز', () {
      final Task original = _task(done: true, completedAt: DateTime(2026, 1, 5, 8));
      final Task clone = original.duplicate(newId: 't2', newDate: DateTime(2026, 1, 6));
      expect(clone.id, 't2');
      expect(clone.date, DateTime(2026, 1, 6));
      expect(clone.done, isFalse);
      expect(clone.completedAt, isNull);
      expect(clone.title, original.title);
    });
  });

  group('الإعدادات والتصنيفات', () {
    test('القيم الافتراضية للتذكير النهائي وأيام الدوام', () {
      final AppSettings settings = AppSettings();
      expect(settings.eveningMinutes, 21 * 60);
      expect(settings.eveningEnabled, isTrue);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.workDays, contains(DateTime.sunday));
      expect(settings.workDays, isNot(contains(DateTime.friday)));
      expect(settings.isArabic, isTrue);
    });

    test('التخزين والاسترجاع (JSON) يحافظ على القيم', () {
      final AppSettings original = AppSettings()
          .copyWith(
            name: 'خالد',
            language: 'en',
            dailyGoal: 7,
            radiusScale: 0.85,
            eveningMinutes: 20 * 60 + 15,
            workDays: <int>{DateTime.monday, DateTime.tuesday},
          );
      final AppSettings restored = AppSettings.fromJson(original.toJson());
      expect(restored.name, 'خالد');
      expect(restored.language, 'en');
      expect(restored.dailyGoal, 7);
      expect(restored.eveningMinutes, 1215);
      expect(restored.radiusScale, closeTo(0.85, 0.001));
      expect(restored.workDays, <int>{DateTime.monday, DateTime.tuesday});
    });

    test('بصمة القنوات تتغيّر مع الصوت والخصوصية', () {
      final AppSettings base = AppSettings();
      final AppSettings louder = base.copyWith(sound: AppSound.chime);
      final AppSettings hidden = base.copyWith(privacyMode: true);
      expect(louder.channelVersion, isNot(base.channelVersion));
      expect(hidden.channelVersion, isNot(base.channelVersion));
    });

    test('التصنيفات الافتراضية كاملة ومتسلسلة', () {
      final List<Category> categories = Defaults.categories();
      expect(categories.length, greaterThanOrEqualTo(6));
      expect(categories.first.id, 'general');
      for (int i = 0; i < categories.length; i++) {
        expect(categories[i].order, i);
        expect(categories[i].name.trim(), isNotEmpty);
      }
      expect(Defaults.badges.length, greaterThanOrEqualTo(8));
      expect(Defaults.quotes, isNotEmpty);
    });

    test('ملاحظة اليوم فارغة افتراضيًا', () {
      expect(DayNote(day: '2026-01-05').isEmpty, isTrue);
      expect(DayNote(day: '2026-01-05', text: 'يوم جيد').isEmpty, isFalse);
    });
  });
}
